# Academic Ingestion Workflow (Shared)

Canonical shared workflow for agent-launched preparation of study materials before academic skill execution.

This workflow sits between:
- raw source materials,
- `scripts/study-materials-prep.py`,
- the academic source-pack contract,
- and downstream skills such as `lecture-transcript`, `homework-management`, and `case-analyzer`.

## Workflow Role

The prep script is not a manual-only converter.
It is a shared ingestion step that an agent or orchestration workflow may launch when academic materials need preparation.

The launching workflow is responsible for:
1. inspecting the incoming source set;
2. deciding whether prep is recommended;
3. running `scripts/study-materials-prep.py`;
4. verifying the resulting source pack before treating it as ready;
5. preserving originals as fallback when conversion is weak;
6. preferring safe merged packs and non-duplicate entries for downstream context.

## When To Launch Prep

Launch prep when:
- materials are spread across many files or folders;
- archives, scans, PDFs, images, or OCR-heavy inputs are present;
- the same course packet will be reused across multiple academic tasks;
- the current raw source set is too fragmented for efficient context loading.

Prep is optional when the user already supplies:
- one readable lecture transcript;
- one short structured case packet;
- a small set of curated excerpts.

## Verification Responsibility

The launching agent/workflow must review:
- `index.json`
- the generated `README.md`
- any entry marked `prepared_status: review_needed`

Minimum verification questions:
- was useful text actually extracted?
- did extraction collapse into noise, OCR artifacts, or placeholder errors?
- are critical numbers, quotes, or terms likely to require the original file?
- should the original file stay prominent in the context packet?

## Prepared Status Semantics

- `prepared_trusted`
  - preferred for downstream academic context loading
  - still not a license to invent unsupported claims
- `review_needed`
  - use only after review by the launching workflow
  - keep `originals/` available as fallback
  - prefer original files for precise quotations, critical facts, and weak OCR cases

## Fallback Rules

Originals must remain available under `originals/`.

Use original fallback prominently when:
- `original_fallback_required: true`
- the file is OCR-heavy
- extraction error markers remain
- the content appears incomplete or suspicious

## Consolidation And Deduplication

The prep workflow may improve downstream usability by:
- marking obvious duplicates with `duplicate_of`
- reducing duplicate entries from the preferred context set
- creating `merged-packs/` for small related fragments when the grouping is clear and safe

Do not:
- merge unrelated files only to reduce file count
- suppress originals
- treat merged packs as better evidence than their source files

Merged packs are for overview and context efficiency.
Member files and originals remain relevant for precise grounding.
