import UIKit
import UniformTypeIdentifiers

// The "share to Frij" entry point: catches a URL (or copied caption text)
// shared from TikTok/Instagram/anywhere, drops it in the App Group inbox, and
// gets out of the way in about a second. The main app drains the inbox on next
// launch/foreground (ImportInbox) and turns each entry into a saved recipe —
// so the extension itself never blocks on a network call.
//
// The confirmation is deliberately theatrical-but-brief: dim, card springs up,
// checkmark pops with a success haptic, then everything animates OUT before
// the sheet is dismissed — an abrupt completeRequest with no exit reads as a
// crash, not a confirmation.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.com.hellofrij.frij"
    private let inboxKey = "frij.importInbox"

    // Frij palette (mirrors DesignSystem.swift).
    private let cream = UIColor(red: 1.0, green: 0.973, blue: 0.894, alpha: 1)
    private let ink = UIColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 1)
    private let green = UIColor(red: 0.45, green: 0.55, blue: 0.40, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        collectSharedValue { [weak self] value in
            DispatchQueue.main.async {
                if let value { self?.stash(value) }
                self?.showConfirmation(saved: value != nil)
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

    // MARK: Confirmation

    private func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let desc = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: desc, size: size)
    }

    private func showConfirmation(saved: Bool) {
        // Dimmed scrim so the card reads as a moment, not a floating box.
        let scrim = UIView()
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        scrim.alpha = 0
        scrim.frame = view.bounds
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrim)

        let card = UIView()
        card.backgroundColor = cream
        card.layer.cornerRadius = 26
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.16
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 10)
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        let icon = UIImageView(image: UIImage(
            systemName: saved ? "checkmark.circle.fill" : "questionmark.circle.fill",
            withConfiguration: iconConfig))
        icon.tintColor = saved ? green : ink.withAlphaComponent(0.35)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = saved ? "Sent to Frij" : "Nothing to import"
        title.font = rounded(20, .bold)
        title.textColor = ink
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = saved ? "Open Frij to see the recipe" : "Share a post or copied recipe text"
        subtitle.font = rounded(14, .medium)
        subtitle.textColor = ink.withAlphaComponent(0.5)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(icon)
        card.addSubview(title)
        card.addSubview(subtitle)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            card.widthAnchor.constraint(equalToConstant: 270),

            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            subtitle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        // ENTRANCE: card springs up from below with a fade; checkmark pops a
        // beat later; success haptic lands with the pop.
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 26).scaledBy(x: 0.88, y: 0.88)
        icon.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        icon.alpha = 0

        UIView.animate(withDuration: 0.2) { scrim.alpha = 1 }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.72,
                       initialSpringVelocity: 0.4) {
            card.alpha = 1
            card.transform = .identity
        }
        UIView.animate(withDuration: 0.45, delay: 0.14, usingSpringWithDamping: 0.55,
                       initialSpringVelocity: 0.6) {
            icon.alpha = 1
            icon.transform = .identity
        }
        if saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }

        // EXIT: staggered, never a cut. The card melts down first (ease-in-out,
        // not ease-in — ease-in reads as "sucked away"), the dim lifts a beat
        // later so the scene has depth on the way out, and only once the screen
        // is fully clear does the sheet dismiss.
        DispatchQueue.main.asyncAfter(deadline: .now() + (saved ? 1.35 : 1.8)) { [weak self] in
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: 0, y: 18).scaledBy(x: 0.94, y: 0.94)
            }
            UIView.animate(withDuration: 0.24, delay: 0.16, options: [.curveEaseInOut]) {
                scrim.alpha = 0
            } completion: { _ in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }
}
