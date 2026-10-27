#!/usr/bin/env python3
"""Convert supplied papal Markdown and explicitly downloaded sources for local demos.

No source-project scripts are executed. No generated summaries, account settings,
credentials or legal approvals are copied. Every imported edition is developmentOnly.
"""
import argparse
import hashlib
import json
import re
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "content/readings"


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Element:
    def __init__(self, tag, attrs=None):
        self.tag = tag; self.attrs = dict(attrs or []); self.children = []

    def walk(self):
        yield self
        for child in self.children:
            if isinstance(child, Element): yield from child.walk()

    def classes(self):
        return set(self.attrs.get("class", "").split())


class Document(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.root = Element("root"); self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Element(tag, attrs); self.stack[-1].children.append(node)
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}: self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs); self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag: self.stack = self.stack[:i]; return

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def render(node, base):
    if isinstance(node, str): return re.sub(r"\s+", " ", node)
    if node.tag in {"script", "style", "noscript", "iframe", "nav", "img"} or node.classes() & {"mw-editsection", "noprint", "toc", "ws-noexport", "va-tools", "share"}: return ""
    text = "".join(render(child, base) for child in node.children)
    if node.tag in {"p", "div", "section", "blockquote", "table", "tr", "ul", "ol"}: return "\n\n" + text.strip() + "\n\n"
    if re.fullmatch(r"h[1-6]", node.tag): return "\n\n" + "#" * int(node.tag[1]) + " " + text.strip() + "\n\n"
    if node.tag == "br": return "\n"
    if node.tag == "li": return "\n\n• " + text.strip() + "\n\n"
    if node.tag in {"td", "th"}: return text + " · "
    if node.tag == "hr": return "\n\n---\n\n"
    if node.tag in {"strong", "b"} and text.strip(): return "**" + text.strip() + "**"
    if node.tag in {"em", "i"} and text.strip(): return "*" + text.strip() + "*"
    if node.tag == "a" and text.strip():
        href = urljoin(base, node.attrs.get("href", ""))
        if href.startswith(("https://", "http://")): return "[" + text.strip() + "](" + href.replace(" ", "%20").replace("(", "%28").replace(")", "%29") + ")"
    return text


def source_markdown(data, url):
    parser = Document(); parser.feed(data.decode("utf-8-sig"))
    nodes = list(parser.root.walk())
    candidates = [n for n in nodes if {"container", "vaticanrichtext"} <= n.classes()]
    if not candidates: candidates = [n for n in nodes if "mw-parser-output" in n.classes()]
    if not candidates: candidates = [n for n in nodes if "entry-content" in n.classes()]
    if len(candidates) != 1: raise ValueError(f"Expected one document body in {url}; found {len(candidates)}")
    text = render(candidates[0], url).replace("\xa0", " ").replace("\u00ad", "")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    if len(text) < 120 or "\ufffd" in text: raise ValueError(f"Empty or malformed source: {url}")
    return text


def text_language(text, fallback):
    words = Counter(re.findall(r"[a-zà-ÿ]+", text.lower()))
    vocabulary = {"en": "the and of that we you our their with which have are from", "it": "che della delle dei gli alla nella nostro vostri noi voi sono dunque essere", "la": "et quod ut atque quae vobis nostri nostrae huius autem quibus eius sunt haec etiam eorum"}
    scores = {code: sum(words[w] for w in terms.split()) for code, terms in vocabulary.items()}
    ordered = sorted(scores, key=scores.get, reverse=True)
    return ordered[0] if scores[ordered[0]] >= 5 and scores[ordered[0]] > scores[ordered[1]] * 1.4 else fallback


def supplied_markdown(data, work):
    text = data.decode("utf-8-sig").strip()
    # The old exporter repeated its page title before the Markdown heading.
    heading = re.search(r"(?m)^# .+$", text)
    if heading and text[:heading.start()].strip() == heading[0][2:].strip(): text = text[heading.start():]
    # Remove the exporter's author/year wrapper, which sometimes used the website's
    # update year. The corrected author and date live in the catalog, not source prose.
    text = re.sub(r"(?m)^\*?Pope [^\n]+ [—–] \d{4}(?:-\d{4})?\*?\s*$", "", text, count=1)
    if not text.startswith("# "): text = "# " + work["title"] + "\n\n" + text
    # The catalog title replaces the exporter's heading, not any document prose.
    text = re.sub(r"\A# [^\n]+", "# " + work["title"], text, count=1)
    # Some source exports have unmatched italic markers on all-capital title lines.
    lines = []
    for line in text.splitlines():
        if line.isupper() and len(re.findall(r"(?<!\\)_", line)) % 2:
            line = re.sub(r"(?<!\\)_", "", line)
        lines.append(line)
    text = "\n".join(lines)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--downloaded-dir", type=Path, required=True)
    args = parser.parse_args()
    inventory = json.loads((DEST / "encyclical-inventory.json").read_text())
    local = {r["id"]: r for r in inventory["records"]}
    downloads = {r["id"]: r for r in json.loads((args.downloaded_dir / "downloads.json").read_text())["sources"]}
    works = json.loads((DEST / "encyclicals.json").read_text())["works"]
    works += json.loads((DEST / "curation.json").read_text())["sourceWorks"]
    overrides = {}; sources = []
    for work in works:
        audit = local.get(work["id"]); translated = bool(audit and audit["translated"])
        if audit:
            path = args.project / "encyclicals/markdown" / (audit["localRecord"] + ".md")
            data = path.read_bytes(); markdown = supplied_markdown(data, work)
            language = "en" if translated else text_language(markdown, "en")
            source = {"id": work["id"], "localRecord": audit["localRecord"], "sourceURL": work["sourceURL"], "sha256": sha(data), "bytes": len(data), "machineTranslated": translated}
            edition = "User-supplied research collection; " + ("unreviewed DeepL English translation from Italian, July 2026." if translated else {"en": "English source edition.", "it": "Italian source text.", "la": "Latin source text."}[language])
        else:
            download = downloads.get(work["id"])
            if not download or "error" in download: raise ValueError(f"Missing downloaded source: {work['id']}")
            data = (args.downloaded_dir / download["file"]).read_bytes()
            if sha(data) != download["sha256"] or len(data) != download["bytes"]: raise ValueError(f"Changed download: {work['id']}")
            markdown = "# " + work["title"] + "\n\n" + source_markdown(data, download["resolvedURL"])
            language = text_language(markdown, work.get("sourceLanguage", "en"))
            source = {k: v for k, v in download.items() if k != "file"}
            source["machineTranslated"] = False
            edition = "Source text retrieved October 27, 2026; " + {"en": "English edition.", "it": "Italian edition.", "la": "Latin edition."}[language]
        if work["id"] == "papal-ben14-sollicita-ac-provida":
            numbers = {int(n) for n in re.findall(r"§\s*(\d+)", markdown)}
            if numbers != set(range(1, 28)): raise ValueError("Sollicita ac provida must retain all 27 numbered sections")
        section_id = work["id"] + "-text"
        relative = f"markdown/{work['id']}/{section_id}.md"
        payload = (markdown.strip() + "\n").encode("utf-8")
        path = DEST / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(payload)
        section = {"id": section_id, "title": "Source excerpts" if work.get("originalType") == "allocution-excerpts" else "Full text", "reference": work["title"], "order": 1, "topics": [], "file": {"path": relative, "sha256": sha(payload), "bytes": len(payload)}}
        overrides[work["id"]] = {"language": language, "summary": "Unreviewed machine translation from Italian. Compare the linked source when accuracy matters." if translated else "Historical papal writing, available offline in this research edition. Transcription and editorial review are pending.",
            "rights": {"status": "developmentOnly", "edition": edition, "statement": "Included at the user's request for local development, demonstration and personal reading. Exact-edition rights review is pending; obtain clearance or remove this text before distribution.", "evidenceURL": work["sourceURL"], "territory": "US"}, "sections": [section]}
        source["readingLanguage"] = language; sources.append(source)
    (DEST / "development-texts.json").write_text(json.dumps({"schemaVersion": 1, "works": overrides}, ensure_ascii=False, indent=2) + "\n")
    (DEST / "development-source-lock.json").write_text(json.dumps({"schemaVersion": 1, "checkedOn": "2026-10-27", "sources": sources}, ensure_ascii=False, indent=2) + "\n")
    print(f"Imported {len(overrides)} development-only papal texts; {sum(s['machineTranslated'] for s in sources)} labeled machine translations; languages {dict(Counter(s['readingLanguage'] for s in sources))}. No approvals created.")


if __name__ == "__main__": main()
