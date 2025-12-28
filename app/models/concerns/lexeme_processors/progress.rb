# app/models/concerns/lexeme_processors/progress.rb
module LexemeProcessors
  module Progress
    extend ActiveSupport::Concern

    def progress_payload(phase:, total:, done:, failed:, error: nil)
      payload = {
        "phase" => phase.to_s,
        "total" => total.to_i,
        "done" => done.to_i,
        "failed" => failed.to_i
      }
      payload["error"] = error.to_s if error.present?
      payload
    end
  end
end