#!/usr/bin/env python3
"""Import bibliographic metadata from the user's processed papal-document corpus.

Read-only access to the original project. No copied document bodies, machine
translations, generated summaries, accounts, or publication approvals are imported.
Optional saved Vatican index pages reconcile direct URLs and identify additions.
This script remains metadata-only; development text import is a separate command.
"""
import argparse
import hashlib
import json
import re
import unicodedata
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse

ROOT = Path(__file__).resolve().parent.parent
POPE_SLUGS = {"ben14": "benedictus-xiv", "clem13": "clemens-xiii", "clem14": "clemens-xiv", "pius06": "pius-vi", "pius07": "pius-vii", "leo12": "leo-xii", "pius08": "pius-viii", "greg16": "gregorius-xvi", "pius09": "pius-ix", "leo13": "leo-xiii", "pius10": "pius-x", "ben15": "benedict-xv", "pius11": "pius-xi", "pius12": "pius-xii", "john23": "john-xxiii", "paul06": "paul-vi", "jp02": "john-paul-ii", "ben16": "benedict-xvi", "franc": "francesco", "leo14": "leo-xiv"}
NAMES = {"ben14": "Benedict XIV", "clem13": "Clement XIII", "clem14": "Clement XIV", "pius06": "Pius VI", "pius07": "Pius VII", "leo12": "Leo XII", "pius08": "Pius VIII", "greg16": "Gregory XVI", "pius09": "Pius IX", "leo13": "Leo XIII", "pius10": "Pius X", "ben15": "Benedict XV", "pius11": "Pius XI", "pius12": "Pius XII", "john23": "John XXIII", "paul06": "Paul VI", "jp02": "John Paul II", "ben16": "Benedict XVI", "franc": "Francis", "leo14": "Leo XIV"}
DIRECTORY = "https://www.papalencyclicals.net/document-directory"
DOCUMENT_TYPES = [(r"(?:Lettera |Epistola |Litterae? )?[Ee]nc[yi]clica(?:e)?", "encyclical", "encyclical-letter"),
                  (r"(?:Lettera |Epistola |Litterae? )[Aa]postolica(?:e)?", "apostolicLetter", "apostolic-letter"),
                  (r"Bolla", "papalDocument", "bull"), (r"Breve", "papalDocument", "brief"),
                  (r"Motu [Pp]roprio", "papalDocument", "motu-proprio"),
                  (r"(?:Costituzione|Constitutio)(?: [Aa]postolica)?", "papalDocument", "apostolic-constitution"),
                  (r"Allocuzione", "papalDocument", "allocution"), (r"Omelia", "papalDocument", "homily"),
                  (r"Esortazione", "papalDocument", "exhortation"), (r"Chirografo", "papalDocument", "chirograph"),
                  (r"Dichiarazione", "papalDocument", "declaration"), (r"Epistola", "apostolicLetter", "letter")]


def official_title(label, url):
    title = re.sub(r"\s*\([^)]*\d{4}[^)]*\).*$", "", label).strip()
    title = re.sub(r"^Encyclical Letter of His Holiness Leo XIV\s*", "", title).strip()
    for prefix, kind, original_type in DOCUMENT_TYPES:
        match = re.match(prefix + r"\s+", title)
        if match: return title[match.end():].strip(), kind, original_type
    return title, "encyclical" if "/encyclicals/" in url else "papalDocument", "encyclical-letter" if "/encyclicals/" in url else "papal-document"


def normalize(value):
    value = value.replace("’", "'").replace("‘", "'")
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()
    value = re.sub(r"\s*\([^)]*\d{4}[^)]*\)\s*$", "", value)
    value = re.sub(r"^encyclical letter of his holiness leo xiv\s*", "", value)
    value = re.sub(r"^(?:enciclica|encyclical(?: letter)?)\s+", "", value)
    value = re.sub(r"^pius xi\s*:?\s*", "", value)
    return " ".join(re.findall(r"[a-z0-9]+", value))


class Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.href = None; self.text = []; self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "a": self.href = dict(attrs).get("href"); self.text = []

    def handle_data(self, data):
        if self.href: self.text.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self.href:
            title = " ".join("".join(self.text).split())
            if re.search(r"\b\d{4}\b", title) and "/documents/" in self.href:
                url = urljoin("https://www.vatican.va", self.href)
                if urlparse(url).hostname == "www.vatican.va": self.links.append((title, url))
            self.href = None


def official_records(directory):
    records = {}; inventory = []
    snapshot = ROOT / "content/readings/vatican-index.json"
    if not directory:
        saved = json.loads(snapshot.read_text())
        return {r["sourceURL"]: r for r in saved["records"]}, saved["indexes"]
    reverse = {value: key for key, value in POPE_SLUGS.items()}
    for path in sorted(directory.glob("*.html")):
        if path.stem not in reverse: continue
        pope = reverse[path.stem]
        parser = Links(); parser.feed(path.read_text())
        seen = set()
        for label, url in parser.links:
            title, kind, original_type = official_title(label, url)
            if url not in seen:
                records[url] = {"title": title, "sourceURL": url, "label": label, "pope": pope, "kind": kind, "originalType": original_type}
                seen.add(url)
        inventory.append({"pope": NAMES[pope], "index": f"https://www.vatican.va/content/{path.stem}/" + ("it.html" if "/it/documents/" in path.read_text() and "/en/encyclicals/" not in path.read_text() else "en/encyclicals.index.html"), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "documentEntries": len(seen), "encyclicalEntries": sum(records[url]["kind"] == "encyclical" for url in seen)})
    snapshot.write_text(json.dumps({"checkedOn": "2026-10-27", "records": list(records.values()), "indexes": inventory}, ensure_ascii=False, indent=2) + "\n")
    return records, inventory


def source_date(label):
    months = {"january": 1, "gennaio": 1, "february": 2, "febbraio": 2, "march": 3, "marzo": 3, "april": 4, "aprile": 4, "may": 5, "maggio": 5, "june": 6, "giugno": 6, "july": 7, "luglio": 7, "august": 8, "agosto": 8, "september": 9, "settembre": 9, "october": 10, "ottobre": 10, "november": 11, "novembre": 11, "december": 12, "dicembre": 12}
    value = label.lower().replace(",", " ").replace("°", "").replace("º", "")
    for month, number in months.items():
        match = re.search(rf"\b(\d{{1,2}})\s+{month}\s+(\d{{4}})\b", value)
        if match: return f"{match[2]}-{number:02d}-{int(match[1]):02d}"
        match = re.search(rf"\b{month}\s+(\d{{1,2}})\s+(\d{{4}})\b", value)
        if match: return f"{match[2]}-{number:02d}-{int(match[1]):02d}"
    match = re.search(r"\b(1[2-9]\d{2}|20\d{2})\b", label)
    return match[0] if match else None


def record(work_id, title, author, kind, source_url, date=None, aliases=None, translated=False, directory=False, original_type=None):
    edition = "Source text as linked; exact English-edition redistribution rights are not recorded."
    if translated: edition += " The local research corpus contains an unreviewed DeepL translation, which is not bundled here."
    if directory: edition += " The original import did not retain an exact source URL; this record opens the collection directory."
    result = {"id": work_id, "title": title, "author": author, "kind": kind, "language": "en", "summary": "Bibliographic record. Read the document in its historical context at the source; editorial classification and edition review are pending.", "aliases": aliases or [], "topics": [], "sourceURL": source_url, "sourceIsDirectory": directory, "originalType": original_type or "encyclical-letter", "rights": {"status": "linkOnly", "edition": edition, "statement": "Source link only. No document text, extracted full-text index, or machine translation is included. Full offline reproduction requires an exact-edition rights assessment.", "evidenceURL": "https://www.vatican.va/content/vatican/en/legal-notes.html" if "vatican.va" in source_url else DIRECTORY, "territory": "US"}, "sections": []}
    if date: result["date"] = str(date)
    if "vatican.va/content/" in source_url: result["sourceLanguage"] = urlparse(source_url).path.split("/")[3]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--vatican-indexes", type=Path)
    parser.add_argument("--output-dir", type=Path, help="Write a comparison catalog without replacing the app's current inventory")
    args = parser.parse_args()
    source = args.project / "encyclicals/markdown"
    raw_index = (source / "index.json").read_bytes()
    index = json.loads(raw_index)
    official, inventories = official_records(args.vatican_indexes)
    recovered = json.loads((ROOT / "content/readings/source-links.json").read_text())["links"]
    corrections = json.loads((ROOT / "content/readings/catalog-corrections.json").read_text())
    overrides = corrections["overrides"]
    source_aliases = corrections.get("sourceAliases", {})
    works = []; audit = []; used = set(); excluded = []
    for item in index["documents"]:
        key = item["popeSlug"] + "/" + item["slug"]
        if key == "pius10/pope-st-pius-x":
            excluded.append({"record": key, "reason": "Biographical note, not a papal document"}); continue
        if key == "jp02/salvifici-doloris":
            excluded.append({"record": key, "reason": "Already represented by the separately curated apostolic letter", "mergedInto": "salvifici-doloris"}); continue
        metadata_path = source / (key + ".json")
        metadata = json.loads(metadata_path.read_text())
        title = item["incipit"]
        if title.strip("- ") == "": title = item["slug"].replace("-", " ").title()
        original_type = item["type"]
        kind = "encyclical" if original_type == "encyclical-letter" else "apostolicLetter" if original_type == "apostolic-letter" else "papalDocument"
        if original_type == "encyclical-letter" and item["popeSlug"] == "pius12" and item["slug"] in {"address-to-midwives-on-the-nature-of-their-profession", "democracy-and-a-lasting-peace", "on-rural-life", "the-internal-order-of-states-and-people", "the-states-of-perfection"}:
            kind = "papalDocument"; original_type = "address"
        # Resolve exact incipits, then unambiguous shortened incipits in the same year.
        # Known transcription errors are explicit, rather than silently fuzzy-matched.
        corrected = {"pius12/communium-interpretes-doloraum": "Communium interpretes dolorum", "leo13/reputantiubus": "Reputantibus", "ben14/ex-quo": "Ex quo primum", "pius11/nos-es-muy-conocida": "Firmissimam constantiam"}.get(key, title)
        candidates = [entry for entry in official.values() if entry["pope"] == item["popeSlug"]]
        exact = [entry for entry in candidates if normalize(entry["title"]) == normalize(corrected)]
        if len(exact) > 1:
            exact = [entry for entry in exact if str(item.get("year")) in entry["label"]]
        retained_url = source_aliases.get(metadata.get("sourceURL"), metadata.get("sourceURL"))
        match = official.get(retained_url) or (exact[0] if len(exact) == 1 else None)
        if match is None:
            short = normalize(corrected)
            extended = [entry for entry in candidates if min(len(short), len(normalize(entry["title"]))) >= 7 and (normalize(entry["title"]).startswith(short + " ") or short.startswith(normalize(entry["title"]) + " "))]
            if len(extended) == 1: match = extended[0]
        if match:
            source_url = match["sourceURL"]; used.add(source_url)
            kind = match.get("kind", "encyclical"); original_type = match.get("originalType", "encyclical-letter")
        else: source_url = metadata.get("sourceURL") or recovered.get(key, DIRECTORY)
        override = overrides.get(key, {})
        source_url = override.get("sourceURL", source_url)
        if source_url in official: used.add(source_url)
        work = record("papal-" + key.replace("/", "-"), match["title"] if match else title, "Pope " + item["popeName"], kind, source_url,
                      source_date(match["label"]) if match else metadata.get("date") or item.get("year"), list(dict.fromkeys(value for value in [title, item.get("englishTitle")] if value and len(value) <= 180)),
                      item.get("translated", False), source_url == DIRECTORY, original_type)
        work.update({k: v for k, v in override.items() if k in {"title", "date", "kind", "originalType", "sourceURL", "sourceLanguage"}})
        works.append(work)
        audit.append({"id": work["id"], "localRecord": key, "metadataSHA256": hashlib.sha256(metadata_path.read_bytes()).hexdigest(), "originalType": item["type"], "importedKind": work["kind"], "translated": item["translated"], "sourceTagsForReview": item["tags"], "sourceURLRecovered": source_url != DIRECTORY})
    unique = {}; translated_ids = {r["id"] for r in audit if r["translated"]}
    for work in works:
        key = (work["author"], normalize(work["title"]), work.get("date", ""))
        if key in unique:
            old = unique[key]
            keep, discard = (work, old) if old["id"] in translated_ids and work["id"] not in translated_ids else (old, work)
            keep["aliases"] = list(dict.fromkeys(keep["aliases"] + discard["aliases"]))
            unique[key] = keep
            excluded.append({"record": discard["id"], "reason": "Duplicate work/edition in the research corpus", "mergedInto": keep["id"]})
        else: unique[key] = work
    works = list(unique.values())
    additions = []
    for item in official.values():
        if item["sourceURL"] in used: continue
        if source_aliases.get(item["sourceURL"]) in used: continue
        title_key = normalize(item["title"])
        work_id = "papal-" + item["pope"] + "-" + title_key.replace(" ", "-")
        year = re.search(r"\b(1[2-9]\d{2}|20\d{2})\b", item["label"])
        if any(w["id"] == work_id for w in works): work_id += "-" + (source_date(item["label"]) or (year[0] if year else "source"))
        if any(w["id"] == work_id for w in works): raise ValueError(f"Ambiguous official document ID: {work_id}")
        works.append(record(work_id, item["title"], "Pope " + NAMES[item["pope"]], item.get("kind", "encyclical"), item["sourceURL"], source_date(item["label"]), original_type=item.get("originalType")))
        additions.append(work_id)
    manual_additions = []
    for item in corrections["additionalWorks"]:
        if any(w["id"] == item["id"] for w in works): continue
        works.append(record(item["id"], item["title"], item["author"], item["kind"], item["sourceURL"], item["date"], item.get("aliases"), original_type=item["originalType"]))
        works[-1]["sourceLanguage"] = item["sourceLanguage"]
        manual_additions.append(item["id"])
    coverage = []
    for item in official.values():
        canonical_url = source_aliases.get(item["sourceURL"], item["sourceURL"])
        matching = [w["id"] for w in works if w["sourceURL"] == canonical_url]
        if len(matching) != 1: raise ValueError(f"Official index entry must resolve once: {item['sourceURL']} {matching}")
        coverage.append({"sourceURL": item["sourceURL"], "workID": matching[0], "canonicalSourceURL": canonical_url})
    if any(w["sourceIsDirectory"] for w in works): raise ValueError("Unresolved source-directory record")
    works.sort(key=lambda w: (w.get("date", ""), w["id"]), reverse=True)
    dest = args.output_dir or ROOT / "content/readings"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "encyclicals.json").write_text(json.dumps({"works": works}, ensure_ascii=False, indent=2) + "\n")
    previous = json.loads((ROOT / "content/readings/encyclical-inventory.json").read_text())
    baseline = previous.get("originalCorpus") or {"sourceDocumentCount": previous["sourceDocumentCount"], "sourceIndexSHA256": previous["sourceIndexSHA256"], "translatedRecords": sum(r["translated"] for r in previous["records"])}
    inventory = {"schemaVersion": 1, "sourceProject": "encyclicals", "sourceIndexSHA256": hashlib.sha256(raw_index).hexdigest(), "sourceIndexGeneratedAt": index["generatedAt"], "checkedOn": "2026-10-27", "completeHistoricalCensusVerified": False, "sourceDocumentCount": len(index["documents"]), "sourcePopeCount": index["totalPopes"], "originalCorpus": baseline, "importedKinds": dict(Counter(w["kind"] for w in works)), "excluded": excluded, "officialIndexAdditions": additions, "manualAdditions": manual_additions, "officialIndexes": inventories, "officialIndexCoverage": coverage, "unresolvedSourceLinks": [], "records": audit}
    (dest / "encyclical-inventory.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n")
    print(f"Cataloged {len(works)} papal works: {dict(Counter(w['kind'] for w in works))}; {sum(not w['sourceIsDirectory'] for w in works)} direct source links; {len(additions)} official-index additions. No source bodies copied.")


if __name__ == "__main__": main()
