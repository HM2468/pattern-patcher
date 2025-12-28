class DropLexemeProcessTables < ActiveRecord::Migration[8.0]
  def change
    drop_table :lexeme_process_results, if_exists: true
    drop_table :lexeme_process_jobs, if_exists: true
    drop_table :lexeme_processes, if_exists: true
  end
end