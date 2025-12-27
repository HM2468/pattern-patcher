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

ActiveRecord::Schema[8.0].define(version: 2025_12_27_080837) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lexeme_processings", force: :cascade do |t|
    t.integer "lexeme_id", null: false
    t.string "process_type"
    t.string "locale"
    t.text "output"
    t.string "provider"
    t.string "model"
    t.string "status"
    t.text "error"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id", "process_type", "locale"], name: "idx_lexeme_processings_unique", unique: true
    t.index ["lexeme_id"], name: "index_lexeme_processings_on_lexeme_id"
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

  create_table "replacement_actions", force: :cascade do |t|
    t.integer "occurrence_id", null: false
    t.integer "repository_file_id", null: false
    t.text "original_fragment"
    t.text "patched_fragment"
    t.text "original_line"
    t.text "patched_line"
    t.string "base_file_sha"
    t.string "decision"
    t.string "status"
    t.datetime "applied_at"
    t.datetime "rejected_at"
    t.text "rejected_reason"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_at"], name: "index_replacement_actions_on_applied_at"
    t.index ["decision"], name: "index_replacement_actions_on_decision"
    t.index ["occurrence_id"], name: "index_replacement_actions_on_occurrence_id"
    t.index ["repository_file_id"], name: "index_replacement_actions_on_repository_file_id"
    t.index ["status"], name: "index_replacement_actions_on_status"
  end

  create_table "replacement_targets", force: :cascade do |t|
    t.integer "lexeme_id", null: false
    t.integer "repository_file_id", null: false
    t.string "target_type"
    t.string "target_value"
    t.string "key_prefix"
    t.text "rendered_code"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id", "repository_file_id", "target_type"], name: "idx_replacement_targets_unique", unique: true
    t.index ["lexeme_id"], name: "index_replacement_targets_on_lexeme_id"
    t.index ["repository_file_id"], name: "index_replacement_targets_on_repository_file_id"
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

  add_foreign_key "lexeme_processings", "lexemes"
  add_foreign_key "occurrences", "lexemes"
  add_foreign_key "occurrences", "lexical_patterns"
  add_foreign_key "occurrences", "repository_files"
  add_foreign_key "occurrences", "scan_runs"
  add_foreign_key "replacement_actions", "occurrences"
  add_foreign_key "replacement_actions", "repository_files"
  add_foreign_key "replacement_targets", "lexemes"
  add_foreign_key "replacement_targets", "repository_files"
  add_foreign_key "repository_files", "repositories"
  add_foreign_key "repository_snapshots", "repositories"
  add_foreign_key "scan_run_files", "repository_files"
  add_foreign_key "scan_run_files", "scan_runs"
  add_foreign_key "scan_runs", "lexical_patterns"
  add_foreign_key "scan_runs", "repository_snapshots"
end
