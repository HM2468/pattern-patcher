# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_28_050259) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lexeme_process_jobs", force: :cascade do |t|
    t.bigint "lexeme_process_id", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "progress_persisted", default: {}, null: false
    t.text "error"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_process_id", "created_at"], name: "index_lexeme_process_jobs_on_lexeme_process_id_and_created_at"
    t.index ["lexeme_process_id"], name: "index_lexeme_process_jobs_on_lexeme_process_id"
    t.index ["status"], name: "index_lexeme_process_jobs_on_status"
  end

  create_table "lexeme_process_results", force: :cascade do |t|
    t.bigint "lexeme_process_job_id", null: false
    t.bigint "lexeme_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "output_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id"], name: "index_lexeme_process_results_on_lexeme_id"
    t.index ["lexeme_process_job_id", "lexeme_id"], name: "idx_lexeme_process_results_unique", unique: true
    t.index ["lexeme_process_job_id"], name: "index_lexeme_process_results_on_lexeme_process_job_id"
  end

  create_table "lexeme_processes", force: :cascade do |t|
    t.string "name", null: false
    t.string "key", null: false
    t.string "entrypoint", null: false
    t.jsonb "default_config", default: {}, null: false
    t.jsonb "output_schema", default: {}, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_lexeme_processes_on_enabled"
    t.index ["key"], name: "index_lexeme_processes_on_key", unique: true
  end

  create_table "lexemes", force: :cascade do |t|
    t.text "source_text"
    t.text "normalized_text"
    t.string "fingerprint"
    t.string "locale"
    t.json "metadata"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_lexemes_on_fingerprint", unique: true
    t.index ["processed_at"], name: "index_lexemes_on_processed_at"
  end

  create_table "lexical_patterns", force: :cascade do |t|
    t.string "name"
    t.text "pattern"
    t.string "language"
    t.string "pattern_type"
    t.integer "priority"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mode", default: "line", null: false
    t.index ["enabled"], name: "index_lexical_patterns_on_enabled"
    t.index ["language", "pattern_type"], name: "index_lexical_patterns_on_language_and_pattern_type"
    t.index ["mode"], name: "index_lexical_patterns_on_mode"
    t.index ["priority"], name: "index_lexical_patterns_on_priority"
  end

  create_table "occurrence_reviews", force: :cascade do |t|
    t.bigint "occurrence_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "rendered_code"
    t.string "status", default: "pending", null: false
    t.string "apply_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["apply_status"], name: "index_occurrence_reviews_on_apply_status"
    t.index ["occurrence_id"], name: "index_occurrence_reviews_on_occurrence_id"
    t.index ["status"], name: "index_occurrence_reviews_on_status"
  end

  create_table "occurrences", force: :cascade do |t|
    t.integer "scan_run_id", null: false
    t.integer "lexeme_id", null: false
    t.integer "lexical_pattern_id", null: false
    t.integer "repository_file_id", null: false
    t.integer "line_at"
    t.integer "line_char_start"
    t.integer "line_char_end"
    t.text "matched_text"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "byte_start"
    t.integer "byte_end"
    t.text "context"
    t.string "match_fingerprint", null: false
    t.index ["lexeme_id", "status"], name: "index_occurrences_on_lexeme_id_and_status"
    t.index ["lexeme_id"], name: "index_occurrences_on_lexeme_id"
    t.index ["lexical_pattern_id"], name: "index_occurrences_on_lexical_pattern_id"
    t.index ["match_fingerprint"], name: "index_occurrences_on_match_fingerprint", unique: true
    t.index ["repository_file_id", "line_at"], name: "index_occurrences_on_repository_file_id_and_line_at"
    t.index ["repository_file_id"], name: "index_occurrences_on_repository_file_id"
    t.index ["scan_run_id"], name: "index_occurrences_on_scan_run_id"
    t.index ["status"], name: "index_occurrences_on_status"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "root_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "permitted_ext"
    t.index ["root_path"], name: "index_repositories_on_root_path", unique: true
  end

  create_table "repository_files", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.string "path"
    t.string "blob_sha"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_sha"], name: "index_repository_files_on_blob_sha"
    t.index ["path"], name: "index_repository_files_on_path"
    t.index ["repository_id", "blob_sha", "path"], name: "index_repository_files_on_repo_blob_path_unique", unique: true
    t.index ["repository_id"], name: "index_repository_files_on_repository_id"
  end

  create_table "repository_snapshots", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.string "commit_sha", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_sha"], name: "index_repository_snapshots_on_commit_sha"
    t.index ["repository_id", "commit_sha"], name: "index_repository_snapshots_on_repository_id_and_commit_sha", unique: true
    t.index ["repository_id"], name: "index_repository_snapshots_on_repository_id"
  end

  create_table "scan_run_files", force: :cascade do |t|
    t.integer "scan_run_id", null: false
    t.integer "repository_file_id", null: false
    t.string "status", default: "pending", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_file_id"], name: "index_scan_run_files_on_repository_file_id"
    t.index ["scan_run_id", "repository_file_id"], name: "index_scan_run_files_on_scan_run_and_repo_file_unique", unique: true
    t.index ["scan_run_id", "status"], name: "index_scan_run_files_on_scan_run_id_and_status"
    t.index ["scan_run_id"], name: "index_scan_run_files_on_scan_run_id"
  end

  create_table "scan_runs", force: :cascade do |t|
    t.integer "lexical_pattern_id", null: false
    t.string "status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text "pattern_snapshot"
    t.text "error"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "repository_snapshot_id", null: false
    t.string "scan_mode", default: "line", null: false
    t.jsonb "progress_persisted", default: {}, null: false
    t.index ["lexical_pattern_id"], name: "index_scan_runs_on_lexical_pattern_id"
    t.index ["repository_snapshot_id"], name: "index_scan_runs_on_repository_snapshot_id"
    t.index ["scan_mode"], name: "index_scan_runs_on_scan_mode"
    t.index ["status"], name: "index_scan_runs_on_status"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  add_foreign_key "lexeme_process_jobs", "lexeme_processes"
  add_foreign_key "lexeme_process_results", "lexeme_process_jobs"
  add_foreign_key "lexeme_process_results", "lexemes"
  add_foreign_key "occurrence_reviews", "occurrences"
  add_foreign_key "occurrences", "lexemes"
  add_foreign_key "occurrences", "lexical_patterns"
  add_foreign_key "occurrences", "repository_files"
  add_foreign_key "occurrences", "scan_runs"
  add_foreign_key "repository_files", "repositories"
  add_foreign_key "repository_snapshots", "repositories"
  add_foreign_key "scan_run_files", "repository_files"
  add_foreign_key "scan_run_files", "scan_runs"
  add_foreign_key "scan_runs", "lexical_patterns"
  add_foreign_key "scan_runs", "repository_snapshots"
end
