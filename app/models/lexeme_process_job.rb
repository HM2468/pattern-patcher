# frozen_string_literal: true
# app/models/lexeme_process_job.rb

class LexemeProcessJob < ApplicationRecord
  belongs_to :lexeme_processor
  has_many :lexeme_process_results, dependent: :delete_all

  STATUSES = %w[pending running succeeded failed].freeze
  DEFAULT_MAX_TOKENS_PER_BATCH = 1_500

  validates :status, inclusion: { in: STATUSES }, presence: true

  # Processor initialization
  def init_processor
    entry = lexeme_processor.entrypoint.to_s.strip
    klass_name = "LexemeProcessors::#{entry}"
    klass = klass_name.constantize
    klass.new(
      config: lexeme_processor.default_config || {},
      processor: lexeme_processor,
      process_job: self
    )
  rescue NameError => e
    Rails.logger&.error(
      "[LexemeProcessJob] processor not found: #{klass_name} (#{e.class}: #{e.message})"
    )
    nil
  rescue => e
    Rails.logger&.error(
      "[LexemeProcessJob] init_processor failed: #{e.class}: #{e.message}"
    )
    nil
  end


  # Progress (Redis keys)
  def progress_namespace
    "lexeme_processing_progress:#{id}"
  end

  def batches_total_key
    "#{progress_namespace}:batches_total"
  end

  def batches_done_key
    "#{progress_namespace}:batches_done"
  end

  def started_at_key
    "#{progress_namespace}:started_at"
  end

  def finalize_lock_key
    "#{progress_namespace}:finalize_lock"
  end

  def total_count_key
    "#{progress_namespace}:total"
  end

  def succeed_count_key
    "#{progress_namespace}:succeeded"
  end

  def failed_count_key
    "#{progress_namespace}:failed"
  end

  # Batch scheduling
  # 根据 token 估算，把 lexemes 切分为多个 batch
  #
  # @param lexemes [Array<Lexeme>]
  # @param max_tokens [Integer] 单个 batch 的最大 token 数
  # @return [Array<Array<Lexeme>>]
  #
  # 注意：
  # - 会按 token 大小排序（long first）
  # - 返回顺序不保证与输入一致
  #
  def batch_by_token(lexemes, max_tokens: nil)
    limit = max_tokens || max_token_size

    items = lexemes.map do |lx|
      text = lx.respond_to?(:normalized_text) ? lx.normalized_text.to_s : ""
      [lx, estimate_tokens(text)]
    end.sort_by { |(_lx, tokens)| -tokens } # long first

    batches = []
    current_batch = []
    current_tokens = 0

    items.each do |lx, tokens|
      # 单条超过上限：单独成批
      if tokens >= limit
        batches << [lx]
        next
      end

      if current_tokens + tokens > limit
        batches << current_batch if current_batch.any?
        current_batch = [lx]
        current_tokens = tokens
        next
      end

      current_batch << lx
      current_tokens += tokens
    end

    batches << current_batch if current_batch.any?
    batches
  end

  private

  # 从 processor config 中读取 batch token 上限
  def max_token_size
    config = lexeme_processor&.default_config || {}
    config['batch_token_limit'] || DEFAULT_MAX_TOKENS_PER_BATCH
  end

  # 粗略 token 估算：UTF-8 bytes / 4
  def estimate_tokens(text)
    s = text.to_s.encode(
      "UTF-8",
      invalid: :replace,
      undef: :replace,
      replace: "�"
    )
    (s.bytesize / 4.0).ceil
  end
end