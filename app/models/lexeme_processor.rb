# app/models/lexeme_processor.rb
class LexemeProcessor < ApplicationRecord
  include LexemeProcessors::EntrypointLoader
  include LexemeProcessors::Progress
  include LexemeProcessors::ResultWriter

  has_many :lexeme_process_jobs, dependent: :delete_all

  validates :name, :key, :entrypoint, presence: true
  validates :key, uniqueness: true

  scope :enabled, -> { where(enabled: true) }

  # 创建一个 job，并 enqueue 分发
  #
  # @param config [Hash] job 覆盖配置
  # @param relation [ActiveRecord::Relation<Lexeme>] 你想处理的 lexemes 范围
  # @param batch_size [Integer]
  #
  # @return [LexemeProcessJob]
  def start_job!(config: {}, relation: Lexeme.all, batch_size: 200)
    raise "Processor disabled" unless enabled?

    final_config = deep_merge_config(default_config, config)

    job = lexeme_process_jobs.create!(
      status: "pending",
      progress_persisted: progress_payload(phase: "enqueue", total: 0, done: 0, failed: 0),
      error: nil,
      started_at: nil,
      finished_at: nil
    )

    LexemeProcessEnqueueJob.perform_later(
      lexeme_process_job_id: job.id,
      batch_size: batch_size,
      config: final_config,
      relation_sql: relation_to_sql(relation)
    )

    job
  end

  # 供 batch job 调用：执行“这一批 lexemes”
  def process_batch!(lexeme_process_job:, lexemes:, config:)
    runner = entrypoint_instance!(config: config, processor: self, job: lexeme_process_job)

    # 优先调用批量接口（更高效），否则降级为单条
    if runner.respond_to?(:call_batch)
      outputs = runner.call_batch(lexemes) # => { lexeme_id => {output_json:, metadata:} }
      write_results!(lexeme_process_job: lexeme_process_job, outputs: outputs)
    else
      lexemes.each do |lex|
        out = runner.call(lex) # => {output_json:, metadata:}
        write_result!(lexeme_process_job: lexeme_process_job, lexeme: lex, output: out)
      end
    end

    true
  end

  private

  # 你可以只支持 ActiveRecord relation；这里用 SQL 还原（更容易在 job 里重建）
  def relation_to_sql(relation)
    relation.select(:id).to_sql
  end

  def deep_merge_config(a, b)
    (a || {}).deep_dup.deep_merge(b || {})
  end
end