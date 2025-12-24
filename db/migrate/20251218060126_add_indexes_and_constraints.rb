class AddIndexesAndConstraints < ActiveRecord::Migration[8.0]
  def change
    # settings
    add_index :settings, :key, unique: true

    # lexical_patterns
    add_index :lexical_patterns, :priority
    add_index :lexical_patterns, [:language, :pattern_type]
    add_index :lexical_patterns, :enabled

    # repositories
    add_index :repositories, :root_path, unique: true
    add_index :repositories, :repo_uid, unique: true
    add_index :repositories, :status

    # repository_files
    add_index :repository_files, [:repository_id, :path], unique: true
    add_index :repository_files, :file_sha

    # scan_runs: A file + a pattern can only be run once (idempotency/gatekeeping basis)
    add_index :scan_runs, [:repository_file_id, :lexical_pattern_id], unique: true
    add_index :scan_runs, :status

    # lexemes: fingerprint must be unique
    add_index :lexemes, :fingerprint, unique: true
    add_index :lexemes, :processed_at

    # occurrences: Common query indexes (review list)
    add_index :occurrences, :status
    add_index :occurrences, [:repository_file_id, :line_at]
    add_index :occurrences, [:lexeme_id, :status]

    # replacement_targets: The unique index you requested (lexeme_id, file_id, target_type)
    add_index :replacement_targets,
              [:lexeme_id, :repository_file_id, :target_type],
              unique: true,
              name: "index_replacement_targets_unique"

    # lexeme_processings: unique index (lexeme_id, process_type, locale)
    add_index :lexeme_processings,
              [:lexeme_id, :process_type, :locale],
              unique: true,
              name: "index_lexeme_processings_unique"

    # replacement_actions: Common for audit queries
    add_index :replacement_actions, :status
    add_index :replacement_actions, :decision
    add_index :replacement_actions, :applied_at
  end
end