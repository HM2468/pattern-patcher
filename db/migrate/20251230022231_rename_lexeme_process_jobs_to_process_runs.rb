# frozen_string_literal: true

class RenameLexemeProcessJobsToProcessRuns < ActiveRecord::Migration[8.0]
  def up
    # 1) 先移除指向 lexeme_process_jobs 的外键（results 表上的）
    if foreign_key_exists?(:lexeme_process_results, :lexeme_process_jobs)
      remove_foreign_key :lexeme_process_results, :lexeme_process_jobs
    end

    # 2) 移除 lexeme_process_jobs -> lexeme_processors 外键（因为要 rename table）
    if foreign_key_exists?(:lexeme_process_jobs, :lexeme_processors)
      remove_foreign_key :lexeme_process_jobs, :lexeme_processors
    end

    # 3) rename 主表
    rename_table :lexeme_process_jobs, :process_runs

    # 4) rename 主表索引（按你 schema 里的名字逐个改）
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

    # 5) results 表：改外键列名
    if column_exists?(:lexeme_process_results, :lexeme_process_job_id)
      rename_column :lexeme_process_results, :lexeme_process_job_id, :process_run_id
    end

    # 6) results 表索引改名（包括 unique 索引）
    if index_name_exists?(:lexeme_process_results, "index_lexeme_process_results_on_lexeme_process_job_id")
      rename_index :lexeme_process_results,
        "index_lexeme_process_results_on_lexeme_process_job_id",
        "index_lexeme_process_results_on_process_run_id"
    end

    # 原 unique index: idx_lexeme_process_results_unique (lexeme_process_job_id, lexeme_id)
    # 改列名后，索引本身仍在，但名字不改也能用；这里按你的要求也改名。
    if index_name_exists?(:lexeme_process_results, "idx_lexeme_process_results_unique")
      rename_index :lexeme_process_results,
        "idx_lexeme_process_results_unique",
        "idx_lexeme_process_results_on_process_run_and_lexeme_unique"
    end

    # 7) 重建外键
    add_foreign_key :process_runs, :lexeme_processors

    add_foreign_key :lexeme_process_results, :process_runs,
      column: :process_run_id

    # （lexeme_process_results -> lexemes 的外键不变，不需要处理）
  end

  def down
    # down 反向操作（保持可回滚）

    if foreign_key_exists?(:lexeme_process_results, :process_runs, column: :process_run_id)
      remove_foreign_key :lexeme_process_results, column: :process_run_id
    end

    remove_foreign_key :process_runs, :lexeme_processors if foreign_key_exists?(:process_runs, :lexeme_processors)

    # results 索引名回滚
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

    # results 列名回滚
    if column_exists?(:lexeme_process_results, :process_run_id)
      rename_column :lexeme_process_results, :process_run_id, :lexeme_process_job_id
    end

    # 主表索引名回滚
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

    # 主表回滚
    rename_table :process_runs, :lexeme_process_jobs

    # 重建外键回滚
    add_foreign_key :lexeme_process_jobs, :lexeme_processors
    add_foreign_key :lexeme_process_results, :lexeme_process_jobs,
      column: :lexeme_process_job_id
  end
end
