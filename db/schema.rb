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

ActiveRecord::Schema[8.1].define(version: 2026_01_20_015749) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lexeme_process_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lexeme_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "output_json", default: {}, null: false
    t.bigint "process_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id"], name: "index_lexeme_process_results_on_lexeme_id"
    t.index ["process_run_id", "lexeme_id"], name: "idx_lexeme_process_results_on_process_run_and_lexeme_unique", unique: true
    t.index ["process_run_id"], name: "index_lexeme_process_results_on_process_run_id"
  end

  create_table "lexeme_processors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "default_config", default: {}, null: false
    t.boolean "enabled", default: true, null: false
    t.string "entrypoint", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.jsonb "output_schema", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_lexeme_processors_on_enabled"
    t.index ["key"], name: "index_lexeme_processors_on_key", unique: true
  end

  create_table "lexemes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fingerprint"
    t.jsonb "metadata"
    t.text "normalized_text"
    t.string "process_status", default: "pending", null: false
    t.datetime "processed_at"
    t.text "source_text"
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_lexemes_on_fingerprint", unique: true
    t.index ["processed_at"], name: "index_lexemes_on_processed_at"
  end

  create_table "lexical_patterns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled"
    t.string "language"
    t.string "name"
    t.text "pattern"
    t.string "scan_mode", default: "line_mode", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_lexical_patterns_on_enabled"
    t.index ["scan_mode"], name: "index_lexical_patterns_on_scan_mode"
  end

  create_table "occurrence_reviews", force: :cascade do |t|
    t.string "apply_status"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "occurrence_id", null: false
    t.text "rendered_code"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["apply_status"], name: "index_occurrence_reviews_on_apply_status"
    t.index ["occurrence_id"], name: "index_occurrence_reviews_on_occurrence_id"
    t.index ["status"], name: "index_occurrence_reviews_on_status"
  end

  create_table "occurrences", force: :cascade do |t|
    t.integer "byte_end"
    t.integer "byte_start"
    t.text "context"
    t.datetime "created_at", null: false
    t.integer "lexeme_id", null: false
    t.integer "lexical_pattern_id", null: false
    t.integer "line_at"
    t.integer "line_char_end"
    t.integer "line_char_start"
    t.string "match_fingerprint", null: false
    t.text "matched_text"
    t.integer "repository_file_id", null: false
    t.integer "scan_run_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["lexeme_id", "status"], name: "index_occurrences_on_lexeme_id_and_status"
    t.index ["lexeme_id"], name: "index_occurrences_on_lexeme_id"
    t.index ["lexical_pattern_id"], name: "index_occurrences_on_lexical_pattern_id"
    t.index ["match_fingerprint"], name: "index_occurrences_on_match_fingerprint", unique: true
    t.index ["repository_file_id", "line_at"], name: "index_occurrences_on_repository_file_id_and_line_at"
    t.index ["repository_file_id"], name: "index_occurrences_on_repository_file_id"
    t.index ["scan_run_id"], name: "index_occurrences_on_scan_run_id"
    t.index ["status"], name: "index_occurrences_on_status"
  end

  create_table "process_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "error"
    t.datetime "finished_at"
    t.bigint "lexeme_processor_id", null: false
    t.jsonb "progress_persisted", default: {}, null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_process_runs_on_deleted_at"
    t.index ["lexeme_processor_id", "created_at"], name: "index_process_runs_on_processor_id_and_created_at"
    t.index ["lexeme_processor_id"], name: "index_process_runs_on_lexeme_processor_id"
    t.index ["status"], name: "index_process_runs_on_status"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "permitted_ext"
    t.string "root_path"
    t.datetime "updated_at", null: false
    t.index ["root_path"], name: "index_repositories_on_root_path", unique: true
  end

  create_table "repository_files", force: :cascade do |t|
    t.string "blob_sha"
    t.datetime "created_at", null: false
    t.string "path"
    t.integer "repository_id", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_sha"], name: "index_repository_files_on_blob_sha"
    t.index ["path"], name: "index_repository_files_on_path"
    t.index ["repository_id", "blob_sha", "path"], name: "index_repository_files_on_repo_blob_path_unique", unique: true
    t.index ["repository_id"], name: "index_repository_files_on_repository_id"
  end

  create_table "repository_snapshots", force: :cascade do |t|
    t.string "commit_sha", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata"
    t.integer "repository_id", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_sha"], name: "index_repository_snapshots_on_commit_sha"
    t.index ["repository_id", "commit_sha"], name: "index_repository_snapshots_on_repository_id_and_commit_sha", unique: true
    t.index ["repository_id"], name: "index_repository_snapshots_on_repository_id"
  end

  create_table "scan_run_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.integer "repository_file_id", null: false
    t.integer "scan_run_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_file_id"], name: "index_scan_run_files_on_repository_file_id"
    t.index ["scan_run_id", "repository_file_id"], name: "index_scan_run_files_on_scan_run_and_repo_file_unique", unique: true
    t.index ["scan_run_id", "status"], name: "index_scan_run_files_on_scan_run_id_and_status"
    t.index ["scan_run_id"], name: "index_scan_run_files_on_scan_run_id"
  end

  create_table "scan_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "error"
    t.datetime "finished_at"
    t.integer "lexical_pattern_id", null: false
    t.text "notes"
    t.jsonb "pattern_snapshot", default: {}, null: false
    t.jsonb "progress_persisted", default: {}, null: false
    t.integer "repository_snapshot_id", null: false
    t.datetime "started_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_scan_runs_on_deleted_at"
    t.index ["lexical_pattern_id"], name: "index_scan_runs_on_lexical_pattern_id"
    t.index ["repository_snapshot_id"], name: "index_scan_runs_on_repository_snapshot_id"
    t.index ["status"], name: "index_scan_runs_on_status"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  add_foreign_key "lexeme_process_results", "lexemes"
  add_foreign_key "lexeme_process_results", "process_runs"
  add_foreign_key "occurrence_reviews", "occurrences"
  add_foreign_key "occurrences", "lexemes"
  add_foreign_key "occurrences", "lexical_patterns"
  add_foreign_key "occurrences", "repository_files"
  add_foreign_key "occurrences", "scan_runs"
  add_foreign_key "process_runs", "lexeme_processors"
  add_foreign_key "repository_files", "repositories"
  add_foreign_key "repository_snapshots", "repositories"
  add_foreign_key "scan_run_files", "repository_files"
  add_foreign_key "scan_run_files", "scan_runs"
  add_foreign_key "scan_runs", "lexical_patterns"
  add_foreign_key "scan_runs", "repository_snapshots"
end
