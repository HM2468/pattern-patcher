# app/models/concerns/lexeme_processors/base.rb
module LexemeProcessors
  class Base
    attr_reader :config, :processor, :job

    def initialize(config:, processor:, job:)
      @config = config || {}
      @processor = processor
      @job = job
    end

    # 单条接口（必须实现其一）
    def call(_lexeme)
      raise NotImplementedError
    end

    # 批量接口（可选实现，性能更好）
    # 返回 { lexeme_id => {output_json:, metadata:} }
    def call_batch(lexemes)
      lexemes.index_with { |lx| call(lx) }
    end
  end
end