# frozen_string_literal: true

class AddCascadeToCoreForeignKeys < ActiveRecord::Migration[8.1]
  def up
    # 1) lexeme_process_results.lexeme_id -> lexemes.id
    remove_foreign_key :lexeme_process_results, :lexemes
    add_foreign_key :lexeme_process_results, :lexemes, on_delete: :cascade

    # 2) occurrence_reviews.occurrence_id -> occurrences.id
    remove_foreign_key :occurrence_reviews, :occurrences
    add_foreign_key :occurrence_reviews, :occurrences, on_delete: :cascade

    # 3) occurrences.lexeme_id -> lexemes.id
    remove_foreign_key :occurrences, :lexemes
    add_foreign_key :occurrences, :lexemes, on_delete: :cascade

    # 4) occurrences.repository_file_id -> repository_files.id
    remove_foreign_key :occurrences, :repository_files
    add_foreign_key :occurrences, :repository_files, on_delete: :cascade

    # 5) repository_files.repository_id -> repositories.id
    remove_foreign_key :repository_files, :repositories
    add_foreign_key :repository_files, :repositories, on_delete: :cascade

    # 6) repository_snapshots.repository_id -> repositories.id
    remove_foreign_key :repository_snapshots, :repositories
    add_foreign_key :repository_snapshots, :repositories, on_delete: :cascade

    # 7) scan_run_files.repository_file_id -> repository_files.id
    remove_foreign_key :scan_run_files, :repository_files
    add_foreign_key :scan_run_files, :repository_files, on_delete: :cascade

    # 8) scan_run_files.scan_run_id -> scan_runs.id
    remove_foreign_key :scan_run_files, :scan_runs
    add_foreign_key :scan_run_files, :scan_runs, on_delete: :cascade
  end

  def down
    remove_foreign_key :lexeme_process_results, :lexemes
    add_foreign_key :lexeme_process_results, :lexemes

    remove_foreign_key :occurrence_reviews, :occurrences
    add_foreign_key :occurrence_reviews, :occurrences

    remove_foreign_key :occurrences, :lexemes
    add_foreign_key :occurrences, :lexemes

    remove_foreign_key :occurrences, :repository_files
    add_foreign_key :occurrences, :repository_files

    remove_foreign_key :repository_files, :repositories
    add_foreign_key :repository_files, :repositories

    remove_foreign_key :repository_snapshots, :repositories
    add_foreign_key :repository_snapshots, :repositories

    remove_foreign_key :scan_run_files, :repository_files
    add_foreign_key :scan_run_files, :repository_files

    remove_foreign_key :scan_run_files, :scan_runs
    add_foreign_key :scan_run_files, :scan_runs
  end
end