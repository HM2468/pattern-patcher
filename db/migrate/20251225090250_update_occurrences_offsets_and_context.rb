# frozen_string_literal: true

class UpdateOccurrencesOffsetsAndContext < ActiveRecord::Migration[8.0]
  def change
    # Rename line offsets (keep semantics: start inclusive, end exclusive)
    rename_column :occurrences, :idx_start, :line_char_start
    rename_column :occurrences, :idx_end,   :line_char_end

    # Add byte offsets for full-file matching (start inclusive, end exclusive)
    add_column :occurrences, :byte_start, :integer
    add_column :occurrences, :byte_end,   :integer

    # Replace context_before/context_after with a single context blob
    add_column :occurrences, :context, :text

    remove_column :occurrences, :context_before, :text
    remove_column :occurrences, :context_after,  :text

    # Optional indexes (only if you expect heavy querying by byte range)
    # add_index :occurrences, [:repository_file_id, :byte_start]
    # add_index :occurrences, [:scan_run_id, :repository_file_id, :byte_start]
  end
end