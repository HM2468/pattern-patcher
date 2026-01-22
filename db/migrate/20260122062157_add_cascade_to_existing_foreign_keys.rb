class AddCascadeToExistingForeignKeys < ActiveRecord::Migration[8.1]
  def up
    # 1) lexeme_process_results.process_run_id -> process_runs.id
    remove_foreign_key :lexeme_process_results, :process_runs
    add_foreign_key :lexeme_process_results, :process_runs, on_delete: :cascade

    # 2) occurrences.lexical_pattern_id -> lexical_patterns.id
    remove_foreign_key :occurrences, :lexical_patterns
    add_foreign_key :occurrences, :lexical_patterns, on_delete: :cascade

    # 3) occurrences.scan_run_id -> scan_runs.id
    remove_foreign_key :occurrences, :scan_runs
    add_foreign_key :occurrences, :scan_runs, on_delete: :cascade

    # 4) process_runs.lexeme_processor_id -> lexeme_processors.id
    remove_foreign_key :process_runs, :lexeme_processors
    add_foreign_key :process_runs, :lexeme_processors, on_delete: :cascade

    # 5) scan_runs.lexical_pattern_id -> lexical_patterns.id
    remove_foreign_key :scan_runs, :lexical_patterns
    add_foreign_key :scan_runs, :lexical_patterns, on_delete: :cascade

    # 6) scan_runs.repository_snapshot_id -> repository_snapshots.id
    remove_foreign_key :scan_runs, :repository_snapshots
    add_foreign_key :scan_runs, :repository_snapshots, on_delete: :cascade
  end

  def down
    remove_foreign_key :lexeme_process_results, :process_runs
    add_foreign_key :lexeme_process_results, :process_runs

    remove_foreign_key :occurrences, :lexical_patterns
    add_foreign_key :occurrences, :lexical_patterns

    remove_foreign_key :occurrences, :scan_runs
    add_foreign_key :occurrences, :scan_runs

    remove_foreign_key :process_runs, :lexeme_processors
    add_foreign_key :process_runs, :lexeme_processors

    remove_foreign_key :scan_runs, :lexical_patterns
    add_foreign_key :scan_runs, :lexical_patterns

    remove_foreign_key :scan_runs, :repository_snapshots
    add_foreign_key :scan_runs, :repository_snapshots
  end
end
