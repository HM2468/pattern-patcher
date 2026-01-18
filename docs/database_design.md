# Database Design

This document describes the database schema of Pattern-Patcher based on the provided schema.rb. It explains what each table does, how tables relate to each other, and why key indexes/constraints exist.

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


## 2. Entity relationship diagram

![ERD Diagram](wiki/erd.svg)

## 3. Table specification


### lexeme_process_results

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| process_run_id | bigint | FK → process_runs.id (required) |
| lexeme_id | bigint | FK → lexemes.id (required) |
| metadata | jsonb | Extra metadata (default {}) |
| output_json | jsonb | Processor output payload (default {}) |



### lexeme_processors

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| name | string | Display name (required) |
| key | string | Stable unique key (required, unique index) |
| entrypoint | string | Processor entrypoint (required) |
| default_config | jsonb | Default processor config (default {}) |
| output_schema | jsonb | Output schema definition (default {}) |
| enabled | boolean | Whether processor is enabled (default true) |



### lexemes

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| source_text | text | Original text |
| normalized_text | text | Normalized text for fingerprinting |
| fingerprint | string | Unique fingerprint (unique index) |
| process_status | string | Processing state (default “pending”, required) |
| metadata | jsonb | Free-form metadata |
| processed_at | datetime | Timestamp for processed records |



### lexical_patterns

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| name | string | Pattern name |
| pattern | text | Regex / pattern source |
| language | string | Language identifier |
| enabled | boolean | Whether pattern is active |
| scan_mode | string | Scan mode (default “line_mode”, required) |



### occurrence_reviews

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| occurrence_id | bigint | FK → occurrences.id (required) |
| metadata | jsonb | Review metadata (default {}) |
| rendered_code | text | Rendered patch / proposed code |
| status | string | Review status (default “pending”, required) |
| apply_status | string | Apply result status (indexed) |



### occurrences

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| scan_run_id | integer | FK → scan_runs.id (required) |
| lexeme_id | integer | FK → lexemes.id (required) |
| lexical_pattern_id | integer | FK → lexical_patterns.id (required) |
| repository_file_id | integer | FK → repository_files.id (required) |
| line_at | integer | Line number |
| line_char_start | integer | Start column (character offset in line) |
| line_char_end | integer | End column (character offset in line) |
| matched_text | text | Matched substring |
| status | string | Occurrence status (indexed) |
| byte_start | integer | Byte start offset |
| byte_end | integer | Byte end offset |
| context | text | Context snippet around match |
| match_fingerprint | string | Unique match identity (required, unique index) |



### process_runs

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| lexeme_processor_id | bigint | FK → lexeme_processors.id (required) |
| status | string | Run status (default “pending”, required) |
| progress_persisted | jsonb | Persisted progress checkpoints (default {}) |
| error | text | Error message / stack |
| started_at | datetime | Start timestamp |
| finished_at | datetime | Finish timestamp |



### repositories

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| name | string | Repository name |
| root_path | string | Local filesystem path (unique index) |
| permitted_ext | string | Allowed file extensions (comma-separated) |



### repository_files

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| repository_id | integer | FK → repositories.id (required) |
| path | string | File path within repository |
| blob_sha | string | Git blob SHA (indexed) |



### repository_snapshots

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| repository_id | integer | FK → repositories.id (required) |
| commit_sha | string | Git commit SHA (required) |
| metadata | jsonb | Snapshot metadata |



### scan_run_files

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| scan_run_id | integer | FK → scan_runs.id (required) |
| repository_file_id | integer | FK → repository_files.id (required) |
| status | string | Status per file (default “pending”, required) |
| error | text | Error for this file (if any) |



### scan_runs

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| lexical_pattern_id | integer | FK → lexical_patterns.id (required) |
| repository_snapshot_id | integer | FK → repository_snapshots.id (required) |
| status | string | Scan run status (indexed) |
| started_at | datetime | Start timestamp |
| finished_at | datetime | Finish timestamp |
| error | text | Error message / stack |
| notes | text | Free-form notes |
| progress_persisted | jsonb | Persisted progress checkpoints (default {}) |
| pattern_snapshot | jsonb | Snapshot of pattern config used (default {}) |



### settings

| attribute | type | note |
| --- | --- | --- |
| id  | bigint | Primary key |
| key | string | Setting key (unique index) |
| value | text | Setting value (stringified) |

