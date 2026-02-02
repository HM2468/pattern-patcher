# frozen_string_literal: true
class RenameLexemeProcessJobsToProcessRuns < ActiveRecord::Migration[8.0]
  def up
    if foreign_key_exists?(:lexeme_process_results, :lexeme_process_jobs)
      remove_foreign_key :lexeme_process_results, :lexeme_process_jobs
    end

    if foreign_key_exists?(:lexeme_process_jobs, :lexeme_processors)
      remove_foreign_key :lexeme_process_jobs, :lexeme_processors
    end

    rename_table :lexeme_process_jobs, :process_runs

    if index_name_exists?(:process_runs, "index_lexeme_process_jobs_on_lexeme_processor_id")
      rename_index :process_runs,
        "index_lexeme_process_jobs_on_lexeme_processor_id",
        "index_process_runs_on_lexeme_processor_id"
    end

    if index_name_exists?(:process_runs, "index_lexeme_process_jobs_on_status")
      rename_index :process_runs,
        "index_lexeme_process_jobs_on_status",
        "index_process_runs_on_status"
    end

    if index_name_exists?(:process_runs, "index_lexeme_process_jobs_on_processor_id_and_created_at")
      rename_index :process_runs,
        "index_lexeme_process_jobs_on_processor_id_and_created_at",
        "index_process_runs_on_processor_id_and_created_at"
    end

    if column_exists?(:lexeme_process_results, :lexeme_process_job_id)
      rename_column :lexeme_process_results, :lexeme_process_job_id, :process_run_id
    end

    if index_name_exists?(:lexeme_process_results, "index_lexeme_process_results_on_lexeme_process_job_id")
      rename_index :lexeme_process_results,
        "index_lexeme_process_results_on_lexeme_process_job_id",
        "index_lexeme_process_results_on_process_run_id"
    end

    if index_name_exists?(:lexeme_process_results, "idx_lexeme_process_results_unique")
      rename_index :lexeme_process_results,
        "idx_lexeme_process_results_unique",
        "idx_lexeme_process_results_on_process_run_and_lexeme_unique"
    end

    add_foreign_key :process_runs, :lexeme_processors

    add_foreign_key :lexeme_process_results, :process_runs,
      column: :process_run_id
  end

  def down
    if foreign_key_exists?(:lexeme_process_results, :process_runs, column: :process_run_id)
      remove_foreign_key :lexeme_process_results, column: :process_run_id
    end

    remove_foreign_key :process_runs, :lexeme_processors if foreign_key_exists?(:process_runs, :lexeme_processors)

    if index_name_exists?(:lexeme_process_results, "index_lexeme_process_results_on_process_run_id")
      rename_index :lexeme_process_results,
        "index_lexeme_process_results_on_process_run_id",
        "index_lexeme_process_results_on_lexeme_process_job_id"
    end

    if index_name_exists?(:lexeme_process_results, "idx_lexeme_process_results_on_process_run_and_lexeme_unique")
      rename_index :lexeme_process_results,
        "idx_lexeme_process_results_on_process_run_and_lexeme_unique",
        "idx_lexeme_process_results_unique"
    end

    if column_exists?(:lexeme_process_results, :process_run_id)
      rename_column :lexeme_process_results, :process_run_id, :lexeme_process_job_id
    end

    if index_name_exists?(:process_runs, "index_process_runs_on_lexeme_processor_id")
      rename_index :process_runs,
        "index_process_runs_on_lexeme_processor_id",
        "index_lexeme_process_jobs_on_lexeme_processor_id"
    end

    if index_name_exists?(:process_runs, "index_process_runs_on_status")
      rename_index :process_runs,
        "index_process_runs_on_status",
        "index_lexeme_process_jobs_on_status"
    end

    if index_name_exists?(:process_runs, "index_process_runs_on_processor_id_and_created_at")
      rename_index :process_runs,
        "index_process_runs_on_processor_id_and_created_at",
        "index_lexeme_process_jobs_on_processor_id_and_created_at"
    end

    rename_table :process_runs, :lexeme_process_jobs

    add_foreign_key :lexeme_process_jobs, :lexeme_processors
    add_foreign_key :lexeme_process_results, :lexeme_process_jobs,
      column: :lexeme_process_job_id
  end
end
