# Reading library

The user expanded the iOS scope on October 27, 2026 to include the complete
Douay–Rheims Bible, a papal-document catalog, Catholic writings, topic discovery,
reading guides, and local Markdown. The same day, the user explicitly authorized
all collected papal texts for **local development, demonstration, and personal
reading**, with legal clearance or removal to follow before distribution.
That authorization is recorded as `developmentOnly`, never as a license or a
human permissions approval. Production publication remains blocked.

## Current collection

- Douay–Rheims American edition of 1899: all 73 Catholic books, 1,334 chapters,
  and 35,811 numbered verses from eBible.org's November 3, 2022 source. Vulgate
  Psalm numbering is retained: Psalm 22 here is Psalm 23 in many modern editions.
  Esther has 16 chapters and Daniel 14. Traditional names and modern aliases work.
- *The Imitation of Christ*, Thomas à Kempis, William Benham translation;
  *Confessions*, Saint Augustine, E. B. Pusey translation; and *The Practice of
  the Presence of God*, Brother Lawrence, the historical Project Gutenberg
  English edition. Introductions and redistribution notices remain.
- 568 papal records: 399 unique works from the user's research collection,
  168 additions from the expanded Vatican-index comparison, and *Sollicita ac
  provida*. A biographical note is excluded and a duplicate *Ubi primum* edition
  is consolidated. *Firmissimam constantiam* and *Nos es muy conocida* resolve
  to one work, retaining the original corpus ID and alternate title.
- A separate *Salvifici doloris* apostolic-letter record, also available offline.
- Fourteen starting topics and two optional reading guides.

All **645 cataloged works** have local text, in **2,060 Markdown sections**.
The Markdown occupies approximately 21.07 MiB and the generated full-text index
41.07 MiB. The index includes precomputed normalized text to reduce first-search
work; excerpts are formatted only after ranking the returned page. Each papal work currently has one reading section. The 569 papal
editions comprise 394 English, 162 Italian, and 13 Latin texts. Thirty-one retained
English editions are explicitly labeled unreviewed DeepL translations. The
Pius X anniversary address is labeled as excerpts because that is what its source
contains; it is not represented as a complete address.

## Catalog reconciliation and provenance

The original import read `/Users/floyd/projects/personal/catholic/encyclicals`
without changing it. Its baseline index had 401 documents across 43 popes,
rather than the older README's 45. Its scripts, CMS, account configuration,
credentials, and generated summaries were not used. The supplied
Markdown is imported directly, retaining original translation notes. Exported
headings are normalized to catalog titles; duplicate titles and author/year
wrappers are removed, and stray italic markers in capitalized front matter are
cleaned. The old wrapper sometimes used the website-update year instead of the
document date. Document prose is preserved.

The 20 Vatican index pages were refreshed on October 27, 2026. All **486 document
entries** resolve exactly once in the catalog. The earlier importer selected
encyclicals from these pages; this comparison also includes their indexed briefs,
bulls, constitutions, letters and other writings, with document types preserved.
The same incipit can identify different documents: Pius VIII's three 1829
*Inter multiplices* briefs retain separate dates and records.

All 568 papal catalog records now have direct HTTPS sources. These seven former
directory fallbacks were checked individually and corrected:

| Work | Direct source | Catalog correction |
| --- | --- | --- |
| Pius X anniversary address | [Papal Encyclicals](https://www.papalencyclicals.net/pius10/p10aniv.htm) | December 12, 1904; allocution excerpts |
| *Misericors Dei Filius* | [Papal Encyclicals](https://www.papalencyclicals.net/leo13/misericors-dei-filius.htm) | May 30, 1883; apostolic constitution |
| *Providas Romanorum* | [Vatican](https://www.vatican.va/content/benedictus-xiv/it/documents/bolla--i-providas-romanorum--i---18-marzo-1751--il-pontefice-con.html) | March 18, 1751; bull |
| *Sollicitudo pastoralis* | [Papal Encyclicals](https://www.papalencyclicals.net/innoc11/soll-l.htm) | November 20, 1679; motu proprio; supplied Latin text |
| *Superna Caelestis* | [Papal Encyclicals](https://www.papalencyclicals.net/sixtus04/superna-caelestis.htm) | April 14, 1482; bull |
| *Romanus Pontifex* | [Papal Encyclicals](https://www.papalencyclicals.net/nichol05/romanus-pontifex.htm) | January 8, 1455; bull; historical closing date retained |
| *Papal Protection of the Jews* | [Papal Encyclicals](https://www.papalencyclicals.net/greg10/g10jprot.htm) | October 7, 1272; bull |

The missing *Sollicita ac provida* is supplied in [Latin](https://la.wikisource.org/wiki/Sollicita_ac_provida),
with all 27 numbered sections checked. None of these source checks constitutes
theological or permissions approval. The catalog is complete against the saved
index snapshots and imported corpus, not a claim to every papal writing in
history. Medieval coverage remains the selected source collection. Availability
of every older direct link has not been independently checked; offline text no
longer depends on those websites staying available.

`encyclical-inventory.json` records source hashes, exclusions, classifications,
additions and every official-index-to-work mapping. `vatican-index.json` stores
bibliographic facts and index hashes. `catalog-corrections.json` records the seven
fixes and manual additions; `source-links.json` preserves recovered links.
`development-source-lock.json` fingerprints every supplied or downloaded papal
edition and records reading language and machine-translation status. Language
detection and research classifications still need editorial review.

The user subsequently requested the findings be added to the source project.
That reconciliation contains 569 canonical works and 572 retained source records,
including alternate editions and a biographical reference. The original 401-record
import remains recorded in this app's inventory. The metadata importer accepts
the expanded index and retained source URLs, preserves the app's work IDs, and
avoids adding *Salvifici doloris* or *Sollicita ac provida* a second time.
Use `--output-dir /path/to/comparison` to inspect a future metadata import before
rebuilding the app library. The two Vatican URLs for the 1937 Mexican letter
resolve to one canonical work in both projects.

## Editions and release boundary

The [eBible notice](https://ebible.org/engDRA/copyright.htm) identifies its exact
1899 Bible text as public domain. Project Gutenberg identifies the three
historical English editions as public domain in the USA; their notices remain.
Those are source statements, not fabricated human approvals.

Papal research copies, including modern editions and supplied translations,
are explicitly `developmentOnly`. The source URL is provenance, not proof of
redistribution permission. No blanket fair-use or personal-use license is asserted.
The [Vatican terms](https://www.vatican.va/content/vatican/en/legal-notes.html)
remain a source for the later exact-edition review. Confidential rights evidence
stays outside public output.

Before distribution, obtain exact-edition rights clearance and the required
editorial, theological, permissions and accessibility approvals, or strip the
development editions using the workflow below. Production rejects a development
manifest, any `developmentOnly` record even after changing the manifest flag,
missing/stale human approvals, or missing durable US offline rights. Source-only
records remain supported and cannot have hidden body text in the search index.

## Discovery and private reading state

Discover opens the Reading library; Scripture opens the full Bible; My prayer
includes Saved readings. Browse by kind and author, filter to offline works, or
search titles, aliases, Bible references and full text locally. Topic aliases
connect “sorrow”, “affliction” and “pain” with suffering selections. Curated
selections rank ahead of related wording; match explanations distinguish topic,
metadata and body matches. No search service or generated doctrinal answer is used.
`Romans 8:18` opens the requested verse; traditional names take precedence over
ambiguous modern aliases. Guides open their offline sections directly.

The reader offers scalable serif text, contents, previous/next navigation,
bookmarks and a last-read section. Research and machine-translation labels appear
before their text, and Italian/Latin editions identify their reading language.
Automatic progress is omitted when Keep prayer activity is disabled. Queries are
temporary view state and are never logged or synchronized.

Bookmarks and the last-read section use a separate versioned file under
`PrivateReading`, complete file protection, backup exclusion and the existing app
lock. An unreadable or unsupported shelf blocks writes until retry or explicit
reset. Clearing activity removes the resume point and preserves bookmarks. Full
reset removes the shelf; the reading library stays available. SwiftData V1 and the
reading-shelf schema remain unchanged.

## Import, build and removal

`library.json` is the manifest; `markdown/<work>/<section>.md` holds source text;
`curation.json` holds topics and original guide notes. The independent public
contract is version 2 in `shared/content-schema/reading-library.schema.json`.
Version 2 adds development-only editions and English/Italian/Latin reading
languages. The client also accepts valid version-1 English manifests, rejects
unknown versions, and rejects version-1 manifests containing version-2 editions.

Normal validation and builds use only local files:

```sh
node tools/readings.mjs validate
make generate
```

Generation derives a deterministic full-text index and copies only referenced
Markdown into the ignored `ios/App/Resources/ReadingLibrary/` folder. Removing an
edition removes its bytes and indexed text from the next generated bundle, even
if its source Markdown remains on disk. Section bytes and checksums must match;
the native reader verifies files before display and the index before search.
Traversal, symlink escapes, corrupt files and unsupported manifests fail closed
without disabling the prayer library.

Explicit source acquisition and conversion are separate from builds:

```sh
python3 tools/import-encyclical-catalog.py --project /path/to/encyclicals \
  --vatican-indexes /path/to/saved/indexes
python3 tools/fetch-reading-sources.py --destination /path/to/downloaded/sources
python3 tools/import-papal-texts.py --project /path/to/encyclicals \
  --downloaded-dir /path/to/downloaded/sources
python3 tools/import-readings.py --bible /path/engDRA_usfm.zip \
  --gutenberg-dir /path/containing/grace-pg1653.txt \
  --encyclicals content/readings/encyclicals.json \
  --development-texts content/readings/development-texts.json
```

The Gutenberg directory also needs `grace-pg3296.txt` and `grace-pg13871.txt`.
Omitting `--vatican-indexes` reuses the committed bibliographic snapshot. Downloads
are explicit, fingerprinted and reusable; the downloader fetches only editions
missing from the supplied corpus. No source-project script or CMS is run.

To **strip all unreviewed papal bodies**, rerun only `import-readings.py` with the
same Bible, Gutenberg and encyclical arguments, **omitting `--development-texts`**,
then run `make generate`. Papal records return to source links and guides adapt.
Check the resulting manifest/index and use a fresh, clean production archive.
This removes bodies from the app bundle, not the local research-source archive.
For selective clearance, review the exact edition and replace or remove its
development overlay record; update the importer policy if mixed reviewed and
development editions are needed. Never relabel an edition without evidence.

Approval format is in `content/reading-reviews/README.md`. The reading library is
updated through app releases; remote reading-pack delivery is not implemented.
