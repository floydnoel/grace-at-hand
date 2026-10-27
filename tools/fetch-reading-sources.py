#!/usr/bin/env python3
"""Explicit research download; normal builds never fetch reading sources.

Download only cataloged documents absent from the user's supplied corpus.
The result is input to import-papal-texts.py, not a publication approval.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    library = ROOT / "content/readings"
    inventory = json.loads((library / "encyclical-inventory.json").read_text())
    supplied = {r["id"] for r in inventory["records"]}
    works = json.loads((library / "encyclicals.json").read_text())["works"]
    works += json.loads((library / "curation.json").read_text())["sourceWorks"]
    previous_path = args.destination / "downloads.json"
    previous = {r["id"]: r for r in json.loads(previous_path.read_text())["sources"]} if previous_path.exists() else {}

    def download(work):
        url = work["sourceURL"]
        if not url.startswith("https://") or work.get("sourceIsDirectory"): raise ValueError("Direct HTTPS source required")
        existing = previous.get(work["id"])
        if existing and existing["url"] == url and (args.destination / existing["file"]).exists():
            data = (args.destination / existing["file"]).read_bytes()
            if hashlib.sha256(data).hexdigest() == existing["sha256"]: return existing
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "GraceAtHandResearch/1.0"})
            with urllib.request.urlopen(request, timeout=35) as response:
                data = response.read(12_000_001)
                final_url = response.url
                content_type = response.headers.get("Content-Type", "")
            if len(data) > 12_000_000 or not final_url.startswith("https://"): raise ValueError("Oversize or insecure download")
            suffix = ".pdf" if data.startswith(b"%PDF") else ".html"
            filename = work["id"] + suffix
            (args.destination / filename).write_bytes(data)
            return {"id": work["id"], "url": url, "resolvedURL": final_url, "file": filename,
                    "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data), "contentType": content_type}
        except Exception as error:
            return {"id": work["id"], "url": url, "error": str(error)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = []
        for item in pool.map(download, [w for w in works if w["id"] not in supplied]):
            results.append(item)
            print(item["id"], item.get("error", f"{item.get('bytes')} bytes"), flush=True)
    (args.destination / "downloads.json").write_text(json.dumps({"checkedOn": "2026-10-27", "sources": results}, indent=2) + "\n")
    if any("error" in r for r in results): raise SystemExit("Some source downloads need attention; successful files are retained.")


if __name__ == "__main__": main()
