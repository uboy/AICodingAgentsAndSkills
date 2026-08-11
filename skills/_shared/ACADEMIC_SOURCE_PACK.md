# Academic Source Pack Contract (Shared)

Shared source-handling contract for the academic runtime.

This contract defines how academic skills should consume prepared study materials and when raw sources are still acceptable.

Related workflow contract:
- `skills/_shared/ACADEMIC_INGESTION_WORKFLOW.md`

## Shared Upstream Layer

The canonical shared source-preparation utility is:
- `scripts/study-materials-prep.py`

Its job is source preparation, not analysis:
- scan source directories recursively,
- extract text from study-material formats,
- unpack archives,
- run OCR when needed,
- write structured Markdown and related metadata.

The prep layer is shared infrastructure for:
- `lecture-transcript`
- `homework-management`
- `case-analyzer`
- future retrieval/helper flows

It is not private to any single skill.

## What A Prepared Source Pack Is

A prepared source pack is a reusable set of extracted study materials that academic skills can consume with fewer implicit assumptions.

Typical shape produced by `study-materials-prep.py`:
- `study-output/<subject>/...` with one `.md` file per extracted source item
- `index.json`
- `README.md`
- `originals/`
- `extracted/`
- `merged-packs/` when safe consolidation improves downstream use

Typical properties of prepared Markdown files:
- preserved relative directory structure
- YAML front matter such as:
  - `title`
  - `subject`
  - `source_file`
  - `processed_at`
  - `original_hash`
  - `word_count`
  - `prepared_status`
  - `review_flags`
  - `original_fallback`
  - `original_fallback_required`
- extracted text content below the front matter

Typical properties of `index.json`:
- `preferred_context_files`
- `review_before_use_files`
- `duplicate_files`
- `merged_packs`
- per-entry source status and fallback metadata

## Safe Assumptions

Academic skills may safely assume that a prepared source pack:
- contains machine-readable Markdown text,
- preserves enough source structure to cite or trace origin,
- may include source metadata helpful for grounding,
- is easier to search and compare than mixed raw files,
- may tell them which files are preferred for context and which require review.

## Unsafe Assumptions

Academic skills must not assume that a prepared source pack:
- is complete,
- is free of OCR or extraction errors,
- resolves all ambiguity automatically,
- contains all materials needed for a confident conclusion,
- is already filtered down to only relevant sources.

Prepared source packs improve usability. They do not remove the need for evidence checking.

## Agent-Launched Ingestion And Verification

The prep layer is launched by an agent/workflow when source preparation is needed.

The launching workflow must:
- inspect the input material set,
- decide whether prep is recommended,
- run `scripts/study-materials-prep.py`,
- review `index.json` and generated `README.md`,
- check entries marked `prepared_status: review_needed`,
- preserve originals as fallback when conversion is weak.

The prep script prepares materials.
It does not decide on its own that every prepared file is equally trustworthy.

## Prepared Status And Fallback

Use these status meanings consistently:

- `prepared_trusted`
  - preferred prepared source form
  - suitable for ordinary downstream context loading
- `review_needed`
  - prepared output exists, but the launching workflow must verify it before relying on it for precise academic claims

Fallback rules:
- `originals/` is part of the source pack, not disposable baggage
- if `original_fallback_required: true`, the original file should remain prominent in the working set
- critical claims, quotations, numbers, formulas, and noisy OCR fragments should be checked against the original when conversion is weak

## Consolidation And Duplicate Handling

Prepared source packs may include:
- `duplicate_of` markers for obvious duplicate content
- `merged-packs/` outputs for small related fragments that are safer to consume as one overview pack

Academic skills may:
- prefer merged packs for overview context,
- ignore duplicate-marked files during first-pass context loading,
- return to member files or originals for precise support.

Academic skills must not:
- assume merged packs replace original evidence,
- assume duplicate suppression means all semantic overlap has been removed perfectly.

## When Prep Is Recommended

Recommend source preparation when:
- the user has many files or directories,
- materials come as archives, scans, PDFs, slides, or mixed formats,
- OCR or extraction is needed before analysis,
- the same materials will be reused across multiple academic skills,
- the operator needs a stable context packet for later RAG or agent loading.

## When Raw Input Is Acceptable

Raw input is acceptable when:
- there is a single lecture transcript or a small set of lecture notes,
- the user provides a short structured case packet directly,
- the user already provides curated excerpts or source fragments,
- the task is narrow enough that additional preparation adds little value.

## Skill-Specific Expectations

### `lecture-transcript`

- Preferred input: raw lecture transcript, lecture notes, or extracted lecture text.
- Prep recommendation: use the prep layer when the lecture source is trapped inside archives, PDFs, scans, or mixed media.
- Not required: a full prepared source pack is not mandatory for ordinary transcript work.

### `homework-management`

- Preferred input: prepared Markdown source pack or a curated set of structured excerpts.
- Raw fallback: direct lecture notes, slides, excerpts, or short document fragments.
- Prep recommendation: strong for multi-source assignments or messy material sets.

### `case-analyzer`

- Preferred input: prepared Markdown case packet or structured excerpts.
- Raw fallback: direct case text plus supporting materials.
- Prep recommendation: strong for multi-document cases or scenarios with mixed evidence sources.

## Incomplete Or Weak Sources

All academic skills consuming this contract must:
- mark missing evidence explicitly,
- distinguish fact from inference,
- treat `review_needed` prepared files as weaker than `prepared_trusted` ones,
- use original fallback for critical claims when conversion quality is weak,
- avoid importing outside knowledge silently,
- prefer `недостаточно данных` to confident fabrication.
