import UIKit
import UniformTypeIdentifiers

// The "share to Frij" entry point: catches a URL (or copied caption text)
// shared from TikTok/Instagram/anywhere, drops it in the App Group inbox, and
// gets out of the way in about a second. The main app drains the inbox on next
// launch/foreground (ImportInbox) and turns each entry into a saved recipe —
// so the extension itself never blocks on a network call.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.com.hellofrij.frij"
    private let inboxKey = "frij.importInbox"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        collectSharedValue { [weak self] value in
            DispatchQueue.main.async {
                if let value { self?.stash(value) }
                self?.showCardAndFinish(saved: value != nil)
            }
        }
    }

    // Prefer a URL; fall back to plain text (someone sharing a copied caption).
    private func collectSharedValue(_ completion: @escaping (String?) -> Void) {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            p.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                completion((item as? URL)?.absoluteString ?? item as? String)
            }
            return
        }
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            p.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                completion(item as? String)
            }
            return
        }
        completion(nil)
    }

    private func stash(_ value: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var inbox = defaults.stringArray(forKey: inboxKey) ?? []
        inbox.append(value)
        // Cap defensively; nobody queues more than a few before opening Frij.
        defaults.set(Array(inbox.suffix(10)), forKey: inboxKey)
    }

    private func showCardAndFinish(saved: Bool) {
        let card = UIView()
        card.backgroundColor = UIColor(red: 1.0, green: 0.973, blue: 0.894, alpha: 1)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = saved ? "Sent to Frij ✓\nOpen Frij to see the recipe" : "Nothing to import here"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor(white: 0.15, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 260),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
        ])

        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.25) {
            card.alpha = 1
            card.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
