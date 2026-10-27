#!/usr/bin/env python3
"""Convert supplied papal texts and English editorial summaries for local demos.

Source-project scripts are never executed. Account settings, credentials, private
evidence and approvals are not imported. Every edition remains developmentOnly,
and every editorial summary remains unreviewed.
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
SUMMARY_TITLE = "English editorial summary"
SUMMARY_NOTICE = "AI-assisted editorial draft in English; not an official translation. Editorial and theological review pending."
LANGUAGES = {"en": "English", "it": "Italian", "la": "Latin"}
PUBLIC_PROVENANCE_KEYS = {
    "source", "reconciledOn", "sourceURL", "resolvedURL", "acquisition",
    "sourceArtifactSHA256", "sourceArtifactBytes", "markdownSHA256",
}


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


def declared_reading_language(metadata, markdown, fallback="en"):
    """The sidecar describes this edition; detection is only a missing-data fallback."""
    language = metadata.get("language")
    if language is not None:
        if language not in LANGUAGES:
            raise ValueError(f"Unsupported supplied reading language: {language}")
        return language
    return text_language(markdown, fallback if fallback in LANGUAGES else "en")


def source_edition(metadata, language, machine_translated):
    edition = metadata.get("rights", {}).get("edition", "").strip()
    if not edition:
        edition = f"User-supplied research collection; {LANGUAGES[language]} source edition."
    if machine_translated and not re.search(r"\b(?:machine|deepl)\b", edition, re.IGNORECASE):
        vendor = "DeepL" if "deepl" in str(metadata.get("translationSource", "")).lower() else "machine"
        edition += f" Unreviewed {vendor} translation."
    return edition


def has_summary_notice(text):
    for paragraph in re.split(r"\n\s*\n", text):
        plain = paragraph.lower()
        if ("english" in plain and "editorial" in plain
                and re.search(r"\b(?:summary|draft)\b", plain)
                and ("unreviewed" in plain or re.search(r"review\s+(?:is\s+)?pending", plain))):
            return True
    return False


def supplied_summary_markdown(data, work):
    """Retain every source heading, paragraph, theme and notice after our label."""
    text = data.decode("utf-8-sig")
    if not text.strip() or "\ufffd" in text:
        raise ValueError(f"Empty or malformed supplied summary: {work['id']}")
    prefix = f"# {work['title']} · {SUMMARY_TITLE}\n\n"
    if not has_summary_notice(text):
        prefix += f"*{SUMMARY_NOTICE}*\n\n"
    return prefix + text + ("" if text.endswith("\n") else "\n")


def summary_overview(data, maximum=420):
    """Use a short plain first paragraph for discovery, not the full summary."""
    text = data.decode("utf-8-sig")
    heading = re.search(r"(?im)^#{1,6}\s+Summary\s*$", text)
    if heading:
        text = text[heading.end():]
    for paragraph in re.split(r"\n\s*\n", text):
        paragraph = paragraph.strip()
        if (not paragraph or paragraph.startswith(("#", "- ", "* ", "[Source"))
                or has_summary_notice(paragraph)):
            continue
        paragraph = re.sub(r"!?\[([^\]]+)\]\([^\n)]+\)", r"\1", paragraph)
        paragraph = re.sub(r"(?m)^\s*>\s?", "", paragraph)
        paragraph = re.sub(r"[`*_]", "", paragraph)
        paragraph = re.sub(r"\s+", " ", paragraph).strip()
        if not paragraph:
            continue
        if len(paragraph) > maximum:
            paragraph = paragraph[:maximum - 1].rsplit(" ", 1)[0].rstrip(" ,;:") + "…"
        return paragraph
    raise ValueError("Supplied summary has no overview paragraph")


def section_record(work, suffix, title, reference, order, payload):
    section_id = work["id"] + "-" + suffix
    relative = f"markdown/{work['id']}/{section_id}.md"
    return {"id": section_id, "title": title, "reference": reference, "order": order,
            "topics": [], "file": {"path": relative, "sha256": sha(payload), "bytes": len(payload)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--downloaded-dir", type=Path, help="Only needed for source bodies absent from the supplied corpus")
    args = parser.parse_args()
    inventory = json.loads((DEST / "encyclical-inventory.json").read_text())
    local = {r["id"]: r for r in inventory["records"]}
    if len(local) != len(inventory["records"]):
        raise ValueError("Duplicate papal source mapping")
    works = json.loads((DEST / "encyclicals.json").read_text())["works"]
    works += json.loads((DEST / "curation.json").read_text())["sourceWorks"]
    if len({w["id"] for w in works}) != len(works):
        raise ValueError("Duplicate papal work ID")
    corpus = args.project / "encyclicals/markdown"
    summaries = {}; metadata_by_id = {}; missing = []; absent_bodies = []
    for work in works:
        audit = local.get(work["id"])
        summary_path = corpus / (audit["localRecord"] + "-summary.md") if audit else None
        if not summary_path or not summary_path.is_file():
            missing.append(work["id"])
            continue
        data = summary_path.read_bytes()
        summaries[work["id"]] = (data, supplied_summary_markdown(data, work), summary_overview(data))
        metadata_path = corpus / (audit["localRecord"] + ".json")
        metadata_by_id[work["id"]] = json.loads(metadata_path.read_text()) if metadata_path.is_file() else {}
        if not (corpus / (audit["localRecord"] + ".md")).is_file():
            absent_bodies.append(work["id"])
    if missing:
        raise ValueError("Missing supplied papal summaries or local mappings: " + ", ".join(missing))
    downloads = {}
    if absent_bodies:
        if args.downloaded_dir is None:
            raise ValueError("Missing supplied papal sources; provide --downloaded-dir for: " + ", ".join(absent_bodies))
        downloads = {r["id"]: r for r in json.loads((args.downloaded_dir / "downloads.json").read_text())["sources"]}
    overrides = {}; sources = []; payloads = {}
    for work in works:
        audit = local[work["id"]]
        metadata = metadata_by_id[work["id"]]
        translated = bool(metadata.get("translated", audit.get("translated", False)))
        machine_translated = bool(metadata.get("machineTranslated", audit.get("machineTranslated", False)))
        path = corpus / (audit["localRecord"] + ".md")
        if path.is_file():
            data = path.read_bytes(); markdown = supplied_markdown(data, work)
            language = declared_reading_language(metadata, markdown, audit.get("readingLanguage", work.get("sourceLanguage", "en")))
            source = {"id": work["id"], "localRecord": audit["localRecord"], "sourceURL": work["sourceURL"], "sha256": sha(data), "bytes": len(data)}
            edition = source_edition(metadata, language, machine_translated)
        else:
            download = downloads.get(work["id"])
            if not download or "error" in download: raise ValueError(f"Missing downloaded source: {work['id']}")
            data = (args.downloaded_dir / download["file"]).read_bytes()
            if sha(data) != download["sha256"] or len(data) != download["bytes"]: raise ValueError(f"Changed download: {work['id']}")
            markdown = "# " + work["title"] + "\n\n" + source_markdown(data, download["resolvedURL"])
            language = declared_reading_language(metadata, markdown, work.get("sourceLanguage", "en"))
            source = {k: download[k] for k in ("id", "sourceURL", "resolvedURL", "sha256", "bytes") if k in download}
            source["localRecord"] = audit["localRecord"]
            translated = machine_translated = False
            edition = f"Source text retrieved October 27, 2026; {LANGUAGES[language]} edition."
        if work["id"] == "papal-ben14-sollicita-ac-provida":
            numbers = {int(n) for n in re.findall(r"§\s*(\d+)", markdown)}
            if numbers != set(range(1, 28)): raise ValueError("Sollicita ac provida must retain all 27 numbered sections")
        payload = (markdown.strip() + "\n").encode("utf-8")
        section = section_record(work, "text", "Source excerpts" if work.get("originalType") == "allocution-excerpts" else "Full text", work["title"], 1, payload)
        summary_data, summary_markdown, overview = summaries[work["id"]]
        summary_payload = summary_markdown.encode("utf-8")
        summary_section = section_record(work, "summary", SUMMARY_TITLE, f"{work['title']} · {SUMMARY_TITLE}", 2, summary_payload)
        payloads[section["file"]["path"]] = payload
        payloads[summary_section["file"]["path"]] = summary_payload
        overrides[work["id"]] = {"language": language, "summary": overview,
            "rights": {"status": "developmentOnly", "edition": edition, "statement": "Included at the user's request for local development, demonstration and personal reading. Exact-edition rights review is pending; obtain clearance or remove this text before distribution.", "evidenceURL": work["sourceURL"], "territory": "US"}, "sections": [section, summary_section]}
        source.update({"readingLanguage": language, "translated": translated, "machineTranslated": machine_translated,
                       "convertedSHA256": sha(payload), "convertedBytes": len(payload), "sectionID": section["id"]})
        if metadata.get("translationSource"):
            source["translationSource"] = metadata["translationSource"]
        provenance = {k: v for k, v in metadata.get("provenance", {}).items() if k in PUBLIC_PROVENANCE_KEYS}
        if provenance:
            source["provenance"] = provenance
        source["summary"] = {"localRecord": audit["localRecord"] + "-summary", "sha256": sha(summary_data), "bytes": len(summary_data),
                             "language": "en", "status": "available-unreviewed", "sectionID": summary_section["id"],
                             "convertedSHA256": sha(summary_payload), "convertedBytes": len(summary_payload)}
        sources.append(source)
    # Validate and prepare the complete corpus before replacing any generated files.
    for relative, payload in payloads.items():
        path = DEST / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(payload)
    (DEST / "development-texts.json").write_text(json.dumps({"schemaVersion": 1, "works": overrides}, ensure_ascii=False, indent=2) + "\n")
    (DEST / "development-source-lock.json").write_text(json.dumps({"schemaVersion": 1, "checkedOn": "2026-10-27", "sources": sources}, ensure_ascii=False, indent=2) + "\n")
    print(f"Imported {len(overrides)} development-only papal texts and {len(sources)} unreviewed English editorial summaries; {sum(s['machineTranslated'] for s in sources)} labeled machine translations; languages {dict(Counter(s['readingLanguage'] for s in sources))}. No approvals created.")


if __name__ == "__main__": main()
