#!/usr/bin/env python3
"""Minimal markdown -> styled HTML for the Frij vision doc.

Only handles the constructs the doc actually uses: headings, bold, italic,
inline code, blockquotes, horizontal rules, bullet + numbered lists, and links.
"""
import html
import re
import sys

CSS = """
@page { margin: 18mm 16mm 20mm 16mm; }
* { box-sizing: border-box; }
body {
  font-family: -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
  font-size: 10.5pt;
  line-height: 1.62;
  color: #22262b;
  margin: 0;
  -webkit-font-smoothing: antialiased;
}
h1 {
  font-size: 25pt; font-weight: 800; letter-spacing: -0.02em;
  margin: 0 0 4pt; color: #14171a; line-height: 1.15;
}
h2 {
  font-size: 15pt; font-weight: 750; letter-spacing: -0.01em;
  margin: 26pt 0 8pt; color: #14171a;
  padding-bottom: 5pt; border-bottom: 1.5px solid #EE7D4D;
  page-break-after: avoid; break-after: avoid;
}
h3 {
  font-size: 11.5pt; font-weight: 700; margin: 16pt 0 5pt; color: #6F876A;
  page-break-after: avoid; break-after: avoid;
}
p { margin: 0 0 8pt; }
ul, ol { margin: 0 0 10pt; padding-left: 17pt; }
li { margin: 0 0 4pt; }
li::marker { color: #EE7D4D; }
blockquote {
  margin: 10pt 0 12pt; padding: 9pt 13pt;
  background: #FEFAEB; border-left: 3px solid #EE7D4D;
  border-radius: 0 5px 5px 0; color: #3a3f45;
  page-break-inside: avoid; break-inside: avoid;
}
blockquote p:last-child { margin-bottom: 0; }
code {
  font-family: "SF Mono", ui-monospace, Menlo, monospace;
  font-size: 9pt; background: #f2f3f5; padding: 1px 4px;
  border-radius: 3px; color: #b3452f;
}
hr { border: 0; border-top: 1px solid #e3e6ea; margin: 20pt 0; }
strong { font-weight: 700; color: #14171a; }
a { color: #3F6B8E; }
.subtitle { color: #6b7178; font-size: 10pt; margin-bottom: 14pt; }
"""


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def convert(md):
    out, list_stack, para, quote = [], [], [], []

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def flush_quote():
        if quote:
            out.append("<blockquote><p>" + inline(" ".join(quote)) + "</p></blockquote>")
            quote.clear()

    def close_lists(to=0):
        while len(list_stack) > to:
            out.append("</ul>" if list_stack.pop() == "ul" else "</ol>")

    for raw in md.split("\n"):
        line = raw.rstrip()

        if not line.strip():
            flush_para(); flush_quote(); close_lists()
            continue

        if re.match(r"^-{3,}$", line.strip()):
            flush_para(); flush_quote(); close_lists()
            out.append("<hr>")
            continue

        h = re.match(r"^(#{1,6})\s+(.*)$", line)
        if h:
            flush_para(); flush_quote(); close_lists()
            lvl = len(h.group(1))
            out.append(f"<h{lvl}>{inline(h.group(2))}</h{lvl}>")
            continue

        q = re.match(r"^>\s?(.*)$", line)
        if q:
            flush_para(); close_lists()
            quote.append(q.group(1))
            continue
        flush_quote()

        li = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if li:
            flush_para()
            depth = len(li.group(1)) // 2 + 1
            kind = "ul" if li.group(2) in "-*" else "ol"
            while len(list_stack) > depth:
                out.append("</ul>" if list_stack.pop() == "ul" else "</ol>")
            while len(list_stack) < depth:
                out.append(f"<{kind}>")
                list_stack.append(kind)
            out.append("<li>" + inline(li.group(3)) + "</li>")
            continue

        # Lazy continuation: the doc wraps list items across lines, so an
        # indented line while a list is open belongs to the previous <li>
        # rather than starting a new paragraph.
        if list_stack and out and out[-1].endswith("</li>"):
            out[-1] = out[-1][: -len("</li>")] + " " + inline(line.strip()) + "</li>"
            continue

        close_lists()
        para.append(line.strip())

    flush_para(); flush_quote(); close_lists()
    return "\n".join(out)


src, dst = sys.argv[1], sys.argv[2]
body = convert(open(src, encoding="utf-8").read())
open(dst, "w", encoding="utf-8").write(
    f"<!doctype html><html><head><meta charset='utf-8'>"
    f"<title>Frij Vision</title><style>{CSS}</style></head><body>{body}</body></html>"
)
print(f"wrote {dst}")
