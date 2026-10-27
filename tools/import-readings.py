#!/usr/bin/env python3
"""Convert explicit, locally downloaded source editions. Never fetch or approve content.

Usage: python3 tools/import-readings.py --bible /path/engDRA_usfm.zip
       --gutenberg-dir /path/containing/grace-pg1653.txt [--encyclicals /path/index.json]
       [--development-texts content/readings/development-texts.json]

Use --reuse-non-papal instead of --bible/--gutenberg-dir to retain the existing,
checksum-verified local Bible and classic editions without their acquisition files.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "content/readings"
PAPAL_KINDS = {"encyclical", "papalDocument", "apostolicLetter"}
CANON = "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH TOB JDT EST JOB PSA PRO ECC SNG WIS SIR ISA JER LAM BAR EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL 1MA 2MA MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV".split()
TRADITIONAL = {"JOS": "Josue", "1SA": "1 Kings", "2SA": "2 Kings", "1KI": "3 Kings", "2KI": "4 Kings", "1CH": "1 Paralipomenon", "2CH": "2 Paralipomenon", "EZR": "1 Esdras", "NEH": "2 Esdras", "TOB": "Tobias", "SNG": "Canticle of Canticles", "WIS": "Wisdom", "SIR": "Ecclesiasticus", "ISA": "Isaias", "JER": "Jeremias", "EZK": "Ezechiel", "HOS": "Osee", "JOL": "Joel", "OBA": "Abdias", "JON": "Jonas", "MIC": "Micheas", "NAM": "Nahum", "HAB": "Habacuc", "ZEP": "Sophonias", "HAG": "Aggeus", "ZEC": "Zacharias", "MAL": "Malachias", "1MA": "1 Machabees", "2MA": "2 Machabees", "REV": "Apocalypse"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_section(work_id, section_id, title, reference, order, markdown, verse_count=None):
    relative = f"markdown/{work_id}/{section_id}.md"
    data = (markdown.strip() + "\n").encode("utf-8")
    path = DEST / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    result = {"id": section_id, "title": title, "reference": reference, "order": order, "topics": [], "file": {"path": relative, "sha256": sha(data), "bytes": len(data)}}
    if verse_count is not None:
        result["verseCount"] = verse_count
    return result


def parse_usfm(text):
    """This edition has only word attributes, chapter/verse and layout markers.

    Fail on unfamiliar markers rather than silently losing footnotes or text.
    Strong-number annotations are not part of the imported translation.
    """
    allowed = {"id", "h", "toc1", "toc2", "toc3", "mt1", "mt2", "mt3", "cl", "c", "v", "p", "q1", "w", "w*"}
    markers = set(re.findall(r"\\([+a-z0-9]+\*?)", text))
    if markers - allowed:
        raise ValueError(f"Unsupported USFM markers: {markers - allowed}")
    text = re.sub(r"\\w ([^|]+)\|[^\n]*?\\w\*", r"\1", text)
    chapters = []
    for match in re.finditer(r"\\c (\d+)\s+([\s\S]*?)(?=\\c \d+|\Z)", text):
        number = int(match[1])
        verses = []
        for verse in re.finditer(r"\\v (\d+)\s+([\s\S]*?)(?=\\v \d+|\Z)", match[2]):
            value = re.sub(r"\\(?:p|q1)\b", " ", verse[2])
            value = re.sub(r"\s+", " ", value).strip()
            if "\\" in value or "strong=" in value or not value:
                raise ValueError("Unconverted markup or empty verse")
            verses.append((int(verse[1]), value))
        if [v[0] for v in verses] != list(range(1, len(verses) + 1)):
            raise ValueError(f"Non-contiguous verse numbering in chapter {number}")
        chapters.append((number, verses))
    if [n for n, _ in chapters] != list(range(1, len(chapters) + 1)):
        raise ValueError("Non-contiguous chapters")
    return chapters


def bible(path):
    works = {}
    with ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.endswith(".usfm"):
                continue
            text = archive.read(name).decode("utf-8-sig")
            code = re.search(r"\\id (\S+)", text)[1]
            modern = re.search(r"\\h (.+)", text)[1].strip()
            traditional = TRADITIONAL.get(code, modern)
            work_id = "drb-" + code.lower()
            sections = []
            for number, verses in parse_usfm(text):
                reference = f"{traditional} {number}"
                sections.append(write_section(work_id, f"{work_id}-{number}", f"Chapter {number}", reference, number,
                    f"# {reference}\n\n" + "\n\n".join(f"**{v}.** {body}" for v, body in verses), len(verses)))
            works[code] = {"id": work_id, "title": traditional if traditional == modern else f"{traditional} ({modern})", "author": "Douay–Rheims Bible", "kind": "bible", "language": "en", "date": "1899", "summary": "Douay–Rheims American edition of 1899. Traditional chapter and verse numbering is retained; Psalms use Vulgate numbering.", "aliases": list(dict.fromkeys([traditional, modern, code, re.search(r"\\toc3 (.+)", text)[1].strip()])), "topics": [], "sourceURL": f"https://ebible.org/engDRA/{code}01.htm", "rights": {"status": "publicDomain", "edition": "Douay–Rheims American Edition, 1899; eBible.org source dated 2022-11-03", "statement": "eBible.org identifies this exact Bible text as public domain. Word-level Strong-number annotations are omitted. Transcription and editorial review remain pending.", "evidenceURL": "https://ebible.org/engDRA/copyright.htm", "territory": "US"}, "sections": sections, "bibleCode": code}
    if set(works) != set(CANON):
        raise ValueError("Source does not contain the complete 73-book Catholic canon")
    if sum(len(w["sections"]) for w in works.values()) != 1334 or sum(s["verseCount"] for w in works.values() for s in w["sections"]) != 35811:
        raise ValueError("Unexpected chapter/verse inventory; inspect the source edition")
    return [works[code] for code in CANON]


def roman(value):
    total = previous = 0
    for letter in value[::-1]:
        current = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}[letter]
        total += -current if current < previous else current
        previous = current
    return total


def gutenberg(path, number, work_id, title, author, kind, edition, topics):
    original = path.read_text(encoding="utf-8-sig")
    start = re.search(r"\*\*\* START OF THE PROJECT GUTENBERG EBOOK .*?\*\*\*", original)
    end = re.search(r"\*\*\* END OF THE PROJECT GUTENBERG EBOOK .*?\*\*\*", original)
    if not start or not end:
        raise ValueError("Missing Gutenberg text and license boundaries")
    body = original[start.end():end.start()].strip()
    # Keep every introductory paragraph, not just the selected chapters.
    if number == 1653:
        # The table of contents is indented; actual book/chapter headings start at column zero.
        pattern = r"(?m)^(?:THE (?:FIRST|SECOND|THIRD|FOURTH) BOOK[^\n]*|CHAPTER [IVXLCDM]+[^\n]*)$"
    elif number == 3296:
        pattern = r"(?m)^BOOK [IVXLCDM]+\s*$"
    else:
        pattern = r"(?m)^(?:PREFACE\.|(?:FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH|TENTH|ELEVENTH|TWELFTH|THIRTEENTH|FOURTEENTH|FIFTEENTH) (?:CONVERSATION|LETTER)\.)$"
    matches = list(re.finditer(pattern, body))
    sections = []
    parts = [("Introduction", "introduction", body[:matches[0].start()] if matches else body)]
    book = 0
    for index, match in enumerate(matches):
        heading = match[0].strip()
        if number == 1653 and heading.startswith("THE "):
            book += 1
            suffix = f"book-{book}-introduction"
        elif number == 1653:
            suffix = f"book-{book}-chapter-{roman(re.search(r'CHAPTER ([IVXLCDM]+)', heading)[1])}"
        elif number == 3296:
            suffix = f"book-{roman(heading.split()[1])}"
        else:
            suffix = re.sub(r"[^a-z]+", "-", heading.lower()).strip("-")
        display = heading.title()
        if number == 1653 and heading.startswith("CHAPTER "):
            display = f"Book {['I', 'II', 'III', 'IV'][book - 1]} · Chapter {re.search(r'CHAPTER ([IVXLCDM]+)', heading)[1]}"
        elif number == 3296:
            display = "Book " + heading.split()[1]
        parts.append((display, suffix, body[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(body)]))
    for heading, suffix, content in parts:
        if content.strip():
            # Join line wrapping inside a paragraph; preserve paragraphs and numbering.
            paragraphs = [re.sub(r"\s*\n\s*", " ", p).strip() for p in re.split(r"\n\s*\n", content.strip())]
            sections.append(write_section(work_id, f"{work_id}-{suffix}", heading, f"{title} · {heading}", len(sections) + 1, f"# {heading}\n\n" + "\n\n".join(paragraphs)))
    notice = original[:start.start()].strip() + "\n\n" + original[end.start():].strip()
    sections.append(write_section(work_id, f"{work_id}-source-notice", "Source and redistribution notice", f"{title} · Source notice", len(sections) + 1, "# Source and redistribution notice\n\n" + notice))
    return {"id": work_id, "title": title, "author": author, "kind": kind, "language": "en", "summary": "Complete source text, divided into reading sections. Introductory matter and the source redistribution notice are retained. Editorial review pending.", "aliases": [], "topics": topics, "sourceURL": f"https://www.gutenberg.org/ebooks/{number}", "rights": {"status": "publicDomain", "edition": edition, "statement": "Project Gutenberg identifies this edition as public domain in the USA. Its source notice and redistribution terms accompany this converted text. No modern translation is substituted.", "evidenceURL": f"https://www.gutenberg.org/ebooks/{number}", "territory": "US"}, "sections": sections}


def reuse_non_papal():
    """Reuse only the established Bible/classics, never old papal text overlays."""
    library = json.loads((DEST / "library.json").read_text())
    if library.get("schemaVersion") not in {1, 2}:
        raise ValueError("Unsupported existing reading library")
    works = [w for w in library["works"] if w["kind"] not in PAPAL_KINDS]
    expected = {"drb-" + code.lower() for code in CANON} | {"imitation", "confessions", "presence-of-god"}
    if len(works) != len(expected) or {w["id"] for w in works} != expected:
        raise ValueError("Existing non-papal library must retain all 73 Bible books and three classics")
    bible_works = [w for w in works if w["kind"] == "bible"]
    if ({w.get("bibleCode") for w in bible_works} != set(CANON)
            or sum(len(w["sections"]) for w in bible_works) != 1334
            or sum(s.get("verseCount", 0) for w in bible_works for s in w["sections"]) != 35811):
        raise ValueError("Unexpected existing Bible chapter/verse inventory")
    for work in works:
        for section in work["sections"]:
            file = section["file"]
            path = (DEST / file["path"]).resolve()
            if not path.is_relative_to(DEST.resolve()):
                raise ValueError("Existing reading section escapes the library")
            data = path.read_bytes()
            if sha(data) != file["sha256"] or len(data) != file["bytes"]:
                raise ValueError(f"Changed existing reading section: {section['id']}")
    source_lock = json.loads((DEST / "source-lock.json").read_text())
    expected_locks = {"drb-1899", "gutenberg-1653", "gutenberg-3296", "gutenberg-13871"}
    locks = [s for s in source_lock["sources"] if s["id"] in expected_locks]
    if len(locks) != len(expected_locks) or {s["id"] for s in locks} != expected_locks:
        raise ValueError("Missing existing Bible/classic source fingerprints")
    return works, locks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bible", type=Path)
    parser.add_argument("--gutenberg-dir", type=Path)
    parser.add_argument("--reuse-non-papal", action="store_true", help="Reuse verified local Bible/classic sections and their source lock")
    parser.add_argument("--encyclicals", type=Path)
    parser.add_argument("--development-texts", type=Path, help="Explicit local-demo editions; never creates rights approvals")
    args = parser.parse_args()
    if args.reuse_non_papal and (args.bible or args.gutenberg_dir):
        parser.error("Use --reuse-non-papal or the Bible/Gutenberg acquisition files, not both")
    if not args.reuse_non_papal and (not args.bible or not args.gutenberg_dir):
        parser.error("Provide --bible and --gutenberg-dir, or --reuse-non-papal")
    curation = json.loads((DEST / "curation.json").read_text())
    editions = [(1653, "imitation", "The Imitation of Christ", "Thomas à Kempis", "spiritualClassic", "William Benham translation; Project Gutenberg #1653", ["prayer", "charity"]), (3296, "confessions", "Confessions", "Saint Augustine of Hippo", "churchFather", "E. B. Pusey translation; Project Gutenberg #3296", ["faith", "mercy"]), (13871, "presence-of-god", "The Practice of the Presence of God", "Brother Lawrence of the Resurrection", "spiritualClassic", "English edition published by Fleming H. Revell; Project Gutenberg #13871", ["prayer", "charity"])]
    if args.reuse_non_papal:
        works, locks = reuse_non_papal()
    else:
        works = bible(args.bible)
        locks = [{"id": "drb-1899", "url": "https://ebible.org/Scriptures/engDRA_usfm.zip", "sha256": sha(args.bible.read_bytes())}]
        for number, *metadata in editions:
            path = args.gutenberg_dir / f"grace-pg{number}.txt"
            works.append(gutenberg(path, number, *metadata))
            locks.append({"id": f"gutenberg-{number}", "url": f"https://www.gutenberg.org/cache/epub/{number}/pg{number}.txt", "sha256": sha(path.read_bytes())})
    works.extend(curation.get("sourceWorks", []))
    if args.encyclicals:
        # Metadata is independent of the optional development-only text overlay.
        imported = json.loads(args.encyclicals.read_text())
        for work in imported["works"]:
            if work["rights"]["status"] != "linkOnly" or work["sections"]:
                raise ValueError("Encyclical metadata import must be link-only; review exact editions separately")
        works.extend(imported["works"])
    if args.development_texts:
        overlay = json.loads(args.development_texts.read_text())
        if overlay.get("schemaVersion") != 1: raise ValueError("Unsupported development-text overlay")
        expected = {w["id"] for w in works if w["kind"] in PAPAL_KINDS}
        if set(overlay["works"]) != expected: raise ValueError("Development texts must cover the exact papal catalog")
        for work in works:
            edition = overlay["works"].get(work["id"])
            if edition:
                if edition["rights"]["status"] != "developmentOnly" or not edition["sections"]: raise ValueError("Invalid development edition")
                work.update(edition)
    by_id = {w["id"]: w for w in works}
    for work in works:
        work["topics"] = sorted(set(work["topics"] + curation.get("workTopics", {}).get(work["id"], [])))
        for section in work["sections"]:
            section["topics"] = curation.get("sectionTopics", {}).get(section["id"], [])
    guides = curation["guides"]
    for guide in guides:
        for step in guide["steps"]:
            if step["workID"] not in by_id:
                raise ValueError(f"Missing guide work: {step['workID']}")
            if not step.get("sectionID") and by_id[step["workID"]]["sections"]:
                step["sectionID"] = by_id[step["workID"]]["sections"][0]["id"]
    library = {"schemaVersion": 2, "revision": "readings-2026-10-27-sync-3", "isDevelopment": True, "coverage": curation["coverage"], "works": works, "topics": curation["topics"], "guides": guides, "searchIndex": {"path": "search-index.json", "sha256": "0" * 64, "bytes": 1}}
    (DEST / "library.json").write_text(json.dumps(library, ensure_ascii=False, indent=2) + "\n")
    (DEST / "source-lock.json").write_text(json.dumps({"schemaVersion": 1, "sources": locks}, indent=2) + "\n")
    subprocess.run(["node", "tools/readings.mjs", "index"], cwd=ROOT, check=True)
    print(f"Imported {len(works)} works and {sum(len(w['sections']) for w in works)} offline sections. No publication approval was created.")


if __name__ == "__main__":
    main()
