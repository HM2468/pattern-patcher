# Pattern-Patcher Database Design Document

This document describes the database schema of Pattern-Patcher based on the provided schema.rb. It explains what each table does, how tables relate to each other, and why key indexes/constraints exist.

## 1. ERD

![ERD Diagram](wiki/erd.svg)

## 1. High-level Data Flow

Pattern-Patcher’s workflow can be summarized as:

1.  Repository ingestion

    - repositories defines a repo workspace.

    - repository_files indexes files in the repo.

    - repository_snapshots pins a repo state by commit_sha.

2.  Scanning

    - lexical_patterns defines scan rules (regex + scan mode).

    - scan_runs executes a scan of a snapshot using a pattern.

    - scan_run_files tracks per-file scan progress/status.

3.  Extraction

    - lexemes stores deduplicated extracted text units (unique by fingerprint).

    - occurrences records each match location in code and links it to a lexeme.

4.  Review & Apply

    - occurrence_reviews stores review status and render context for an occurrence.
5.  Processing (LLM / batch transformations)

    - lexeme_processors defines a processing “tool” (entrypoint + schema).

    - process_runs tracks a run of a processor.

    - lexeme_process_results stores per-lexeme outputs for a given process run.

6.  Global configuration

    - settings stores key/value runtime configuration.



## 2. Table-by-table Documentation

### 2.1 repositories  — Repository Registry

| Item | Details |
| --- | --- |
| Purpose | Represents a local/imported Git repository workspace that Pattern-Patcher can scan. |
| Primary Key | id  |
| Key Columns | name (display), root_path (repo path), permitted_ext (allowed file extensions) |
| Notable Indexes | root_path is unique to prevent importing the same workspace twice. |
| Relationships | Has many repository_files, has many repository_snapshots. |

Why it exists: a stable anchor for file indexing and snapshots across multiple scans.



### 2.2 repository_files — File Index within a Repository

| Item | Details |
| --- | --- |
| Purpose | Stores the list of files for a repository, including path and file content identity (blob_sha). |
| Primary Key | id  |
| Foreign Keys | repository_id → repositories.id |
| Key Columns | path (relative path), blob_sha (Git blob SHA for content identity) |
| Notable Indexes | (repository_id, blob_sha, path) unique to avoid duplicates; indexes on repository_id, path, blob_sha. |
| Relationships | Belongs to repository; referenced by occurrences and scan_run_files. |

Why it exists: enables fast file listing/filtering and stable reference for occurrences and scan tasks.



### 2.3 repository_snapshots — Repository Snapshot by Commit

| Item | Details |
| --- | --- |
| Purpose | Pins a repository state by commit_sha, ensuring scans are reproducible and auditable. |
| Primary Key | id  |
| Foreign Keys | repository_id → repositories.id |
| Key Columns | commit_sha (snapshot commit), metadata (extra info like branch/tag/author, etc.) |
| Notable Indexes | (repository_id, commit_sha) unique; index on commit_sha. |
| Relationships | Belongs to repository; referenced by scan_runs. |

Why it exists: results must be tied to an immutable code version; scans should not depend on moving branches.



### 2.4 lexical_patterns  — Scan Pattern Definitions

| Item | Details |
| --- | --- |
| Purpose | Defines scanning rules (regex patterns) and scanning behavior (scan_mode). |
| Primary Key | id  |
| Key Columns | name, pattern (regex), language, enabled, scan_mode (default line_mode) |
| Notable Indexes | index on enabled and scan_mode for quickly selecting active patterns. |
| Relationships | Referenced by scan_runs and occurrences. |

Why it exists: Pattern-Patcher relies on “divide-and-conquer” scanning; each pattern is a configurable unit.



### 2.5 scan_runs  — Scan Execution (Pattern × Snapshot)

| Item | Details |
| --- | --- |
| Purpose | Represents a scan run that applies one lexical pattern to one repository snapshot. Tracks lifecycle and progress. |
| Primary Key | id  |
| Foreign Keys | lexical_pattern_id → lexical_patterns.id; repository_snapshot_id → repository_snapshots.id |
| Key Columns | status, started_at, finished_at, error, notes, progress_persisted (jsonb), pattern_snapshot (jsonb) |
| Notable Indexes | indexes on lexical_pattern_id, repository_snapshot_id, status. |
| Relationships | Has many scan_run_files; referenced by occurrences. |

Design notes:

- pattern_snapshot stores the pattern config used at runtime (important if patterns evolve later).

- progress_persisted stores resumable progress checkpoints (for large repos).




### 2.6 scan_run_files  — Per-file Scan Tracking

| Item | Details |
| --- | --- |
| Purpose | Tracks scan status for each file within a scan run (pending/processed/failed style workflow). |
| Primary Key | id  |
| Foreign Keys | scan_run_id → scan_runs.id; repository_file_id → repository_files.id |
| Key Columns | status (default pending), error |
| Notable Indexes | (scan_run_id, repository_file_id) unique to ensure one row per file per run; index on (scan_run_id, status) for work scheduling. |
| Relationships | Belongs to scan_run; belongs to repository_file. |

Why it exists: file-level tracking is essential for reliability (retry failed files, parallelize safely, show progress UI).



### 2.7 lexemes  — Deduplicated Text Units (String Fingerprints)

| Item | Details |
| --- | --- |
| Purpose | Stores unique text units extracted from source code (e.g., hard-coded Chinese strings) deduplicated by fingerprint. |
| Primary Key | id  |
| Key Columns | source_text, normalized_text, fingerprint (unique), process_status (default pending), metadata, processed_at |
| Notable Indexes | fingerprint unique; index on processed_at for tracking pipeline progress. |
| Relationships | Referenced by occurrences and lexeme_process_results. |

Design notes:

- fingerprint is the primary dedup key (hash of normalized text / canonical form).

- process_status enables a processing pipeline state machine (pending → processed, etc.).




### 2.8 occurrences — Match Locations in Code

| Item | Details |
| --- | --- |
| Purpose | Records each match found by scanning: where it occurs, what matched, and what lexeme it maps to. |
| Primary Key | id  |
| Foreign Keys | scan_run_id → scan_runs.id; lexeme_id → lexemes.id; lexical_pattern_id → lexical_patterns.id; repository_file_id → repository_files.id |
| Key Columns | line_at, line_char_start, line_char_end, byte_start, byte_end, matched_text, context, status, match_fingerprint (unique) |
| Notable Indexes | match_fingerprint unique; indexes on scan_run_id, repository_file_id, lexeme_id, status, and (lexeme_id, status). |
| Relationships | Has one occurrence_review (via occurrence_reviews); belongs to file/pattern/scan_run/lexeme. |

Design notes:

- match_fingerprint uniquely identifies an occurrence to prevent duplicates across re-runs or repeated ingestion.

- Both line-based and byte-based offsets allow reliable patching and rendering across file encodings.




### 2.9 occurrence_reviews  — Human Review & Apply Tracking

| Item | Details |
| --- | --- |
| Purpose | Stores review state and UI rendering context for an occurrence, and tracks apply status of patches. |
| Primary Key | id  |
| Foreign Keys | occurrence_id → occurrences.id |
| Key Columns | status (default pending), apply_status, rendered_code (preview), metadata (jsonb) |
| Notable Indexes | indexes on status, apply_status, occurrence_id. |
| Relationships | Belongs to occurrence. |

Design notes:

- status is review lifecycle (pending/approved/rejected etc. depending on app enums).

- apply_status allows separating “review decision” from “patch application result” (applied/failed/conflict).




### 2.10 lexeme_processors — Processor Registry (Pluggable Processing)

| Item | Details |
| --- | --- |
| Purpose | Defines processing modules (e.g., translation, key generation, normalization). Think “pluggable pipeline steps.” |
| Primary Key | id  |
| Key Columns | name, key (unique), entrypoint (code path/class), default_config (jsonb), output_schema (jsonb), enabled |
| Notable Indexes | key unique; index on enabled. |
| Relationships | Has many process_runs. |

Design notes:

- output_schema is useful for validation/contracting processor outputs (especially for LLM output shape).



### 2.11 process_runs — Processor Run Tracking

| Item | Details |
| --- | --- |
| Purpose | Tracks each execution of a processor (batch run), including progress, status, and errors. |
| Primary Key | id  |
| Foreign Keys | lexeme_processor_id → lexeme_processors.id |
| Key Columns | status (default pending), progress_persisted (jsonb), error, started_at, finished_at |
| Notable Indexes | index on status; indexes on lexeme_processor_id and (lexeme_processor_id, created_at) for listing run history. |
| Relationships | Belongs to lexeme_processor; has many lexeme_process_results. |

Design notes:

- progress_persisted supports resumable processing (important for long LLM jobs).



### 2.12 lexeme_process_results — Per-lexeme Output for a Run

| Item | Details |
| --- | --- |
| Purpose | Stores the output of a processing run for each lexeme (e.g., translation, suggested key, metadata). |
| Primary Key | id  |
| Foreign Keys | process_run_id → process_runs.id; lexeme_id → lexemes.id |
| Key Columns | output_json (jsonb), metadata (jsonb) |
| Notable Indexes | (process_run_id, lexeme_id) unique; indexes on process_run_id and lexeme_id. |
| Relationships | Belongs to process_run; belongs to lexeme. |

Design notes:

- The unique constraint ensures one result per lexeme per run, enabling safe reprocessing (upsert patterns).



### 2.13 settings — Global Key/Value Settings

| Item | Details |
| --- | --- |
| Purpose | Stores application configuration as key/value pairs. |
| Primary Key | id  |
| Key Columns | key (unique), value (text) |
| Notable Indexes | key is unique. |
| Relationships | None (global table). |

Design notes:

- Useful for feature flags, default processor selections, UI behavior toggles, etc.



## 3. Relationship Summary (ER-style)

- repositories

    - 1 → N repository_files

    - 1 → N repository_snapshots

- repository_snapshots

    - 1 → N scan_runs
- lexical_patterns

    - 1 → N scan_runs

    - 1 → N occurrences

- scan_runs

    - 1 → N scan_run_files

    - 1 → N occurrences

- repository_files

    - 1 → N occurrences

    - 1 → N scan_run_files

- lexemes

    - 1 → N occurrences

    - 1 → N lexeme_process_results

- occurrences

    - 1 → 1 (conceptually) occurrence_reviews (schema does not enforce uniqueness but model likely does)
- lexeme_processors

    - 1 → N process_runs
- process_runs

    - 1 → N lexeme_process_results



## 4. Index/Constraint Rationale (Key Ones)

| Constraint / Index | Why it matters |
| --- | --- |
| lexemes.fingerprint UNIQUE | Deduplicates extracted strings globally; enables stable lexeme identity. |
| occurrences.match_fingerprint UNIQUE | Prevents duplicate occurrences; supports idempotent scanning. |
| scan_run_files (scan_run_id, repository_file_id) UNIQUE | One file tracking row per scan run; enables reliable retry/scheduling. |
| lexeme_process_results (process_run_id, lexeme_id) UNIQUE | One output per lexeme per run; safe upsert/re-run semantics. |
| repository_snapshots (repository_id, commit_sha) UNIQUE | One snapshot per commit per repo; reproducible scans. |
| repositories.root_path UNIQUE | Prevents duplicate imported workspaces. |



## 5. Practical Notes / Potential Enhancements (Optional)

These are not required by your schema, but are typical hardening steps:

- Add a unique index on occurrence_reviews.occurrence_id if the design is strictly 1:1.

- Standardize status columns as enums with constraints (e.g., CHECK constraints) to prevent invalid states.

- Consider adding not null constraints for commonly required columns (e.g., repository_files.path).

- Add created_at ordering indexes if you frequently page through large tables (especially occurrences).



