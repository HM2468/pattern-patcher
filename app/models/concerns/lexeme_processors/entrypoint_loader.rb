# app/models/concerns/lexeme_processors/entrypoint_loader.rb
module LexemeProcessors
  module EntrypointLoader
    extend ActiveSupport::Concern

    # entrypoint 支持：
    # - "LexemeProcessors::LocalizeRails"（推荐）
    # - "LocalizeRails"（你自己定义也行）
    def entrypoint_class
      entrypoint.to_s.constantize
    rescue NameError => e
      raise "Invalid entrypoint=#{entrypoint}: #{e.message}"
    end

    def entrypoint_instance!(config:, processor:, job:)
      klass = entrypoint_class
      # 约定：processor 实现 initialize(config:, processor:, job:)
      klass.new(config: config, processor: processor, job: job)
    end
  end
end