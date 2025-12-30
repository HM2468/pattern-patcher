# frozen_string_literal: true
# app/services/lexeme_processors/progress_broadcaster.rb

module LexemeProcessors
  class ProgressBroadcaster
    CHANNEL = "process_runs"
    DEFAULT_THROTTLE_WINDOW = 0.5 # seconds

    class << self
      # 实时进度广播（带节流）：从 Redis 读计数拼 payload
      def broadcast_progress_throttled(run, throttle_window: DEFAULT_THROTTLE_WINDOW)
        return if run.nil?
        return if %w[succeeded failed].include?(run.status)
        return unless acquire_throttle!(run, window: throttle_window)

        payload = build_progress_payload_from_cache(run)
        return if payload.nil?

        broadcast(run, payload: payload, kind: "progress")
      rescue => e
        Rails.logger&.error("[ProgressBroadcaster] broadcast_progress_throttled failed run_id=#{run&.id} err=#{e.class}: #{e.message}")
      end

      # 最终结果广播：payload 由 finalize 生成并持久化后传入
      def broadcast_final(run, payload:)
        return if run.nil?
        broadcast(run, payload: payload.merge(status: run.status), kind: "final")
      rescue => e
        Rails.logger&.error("[ProgressBroadcaster] broadcast_final failed run_id=#{run&.id} err=#{e.class}: #{e.message}")
      end

      # 可选：started 广播（dispatcher 用）
      def broadcast_started(run)
        return if run.nil?
        payload = build_progress_payload_from_cache(run)
        payload ||= { status: run.status }
        broadcast(run, payload: payload, kind: "started")
      rescue => e
        Rails.logger&.error("[ProgressBroadcaster] broadcast_started failed run_id=#{run&.id} err=#{e.class}: #{e.message}")
      end

      private

      def broadcast(run, payload:, kind:)
        ActionCable.server.broadcast(
          CHANNEL,
          {
            id: run.id,
            kind: kind,
            ts: Time.current.to_i,
            payload: payload
          }
        )
      end

      # 从 Redis（Rails.cache）拼实时进度 payload
      def build_progress_payload_from_cache(run)
        total = Rails.cache.read(run.total_count_key).to_i
        succ  = Rails.cache.read(run.succeed_count_key).to_i
        failc = Rails.cache.read(run.failed_count_key).to_i
        batches_total = Rails.cache.read(run.batches_total_key).to_i
        batches_done  = Rails.cache.read(run.batches_done_key).to_i
        started_at_ts = Rails.cache.read(run.started_at_key).to_i
        started_at    = started_at_ts > 0 ? Time.at(started_at_ts) : nil
        processed = succ + failc
        percent =
          if total > 0
            ((processed.to_f / total) * 100).clamp(0, 100).round(2)
          else
            0.0
          end

        {
          status: run.status,
          total: total,
          succeeded: succ,
          failed: failc,
          processed: processed,
          percent: percent,
          batches_total: batches_total,
          batches_done: batches_done,
          started_at: started_at&.iso8601
        }
      end

      # 节流：在一个时间窗内只允许一个 worker 发一次
      # 依赖 RedisCacheStore 的原子写入：unless_exist: true
      # window 到期 key 自动过期，下一次才能抢到
      def acquire_throttle!(run, window:)
        key = throttle_key(run)
        Rails.cache.write(key, 1, expires_in: window, unless_exist: true)
      rescue => e
        Rails.logger&.error("[ProgressBroadcaster] acquire_throttle failed run_id=#{run&.id} err=#{e.class}: #{e.message}")
        # 节流失败时，保守起见不广播（避免刷爆）
        false
      end

      def throttle_key(run)
        "#{run.progress_namespace}:broadcast_throttle"
      end
    end
  end
end