# frozen_string_literal: true
# app/models/concerns/process_run_broadcastor.rb

module ProcessRunBroadcastor
  extend ActiveSupport::Concern

  CHANNEL = "process_runs"
  DEFAULT_THROTTLE_WINDOW = 0.5 # seconds

  # Public instance methods
  # Broadcast progress with throttling
  def broadcast_progress_throttled(throttle_window: DEFAULT_THROTTLE_WINDOW)
    return if terminal_status?
    return unless acquire_broadcast_throttle!(window: throttle_window)

    payload = build_progress_payload_from_cache
    return if payload.nil?

    broadcast(payload: payload, kind: "progress")
  rescue => e
    Rails.logger&.error(
      "[ProcessRunBroadcastor] broadcast_progress_throttled failed run_id=#{id} err=#{e.class}: #{e.message}"
    )
  end

  def broadcast_final(payload:)
    broadcast(payload: payload.merge(status: status), kind: "final")
  rescue => e
    Rails.logger&.error(
      "[ProcessRunBroadcastor] broadcast_final failed run_id=#{id} err=#{e.class}: #{e.message}"
    )
  end

  def build_progress_payload_from_cache
    total = read_counter(total_count_key)
    succ  = read_counter(succeed_count_key)
    failc = read_counter(failed_count_key)
    occ_revc = read_counter(occ_rev_count_key)
    batches_total = read_counter(batches_total_key)
    batches_done  = read_counter(batches_done_key)

    processed = succ + failc
    percent =
      if total.positive?
        ((processed.to_f / total) * 100).clamp(0, 100).round(2)
      else
        0.0
      end

    {
      status: status,
      total: total,
      succeeded: succ,
      failed: failc,
      processed: processed,
      percent: percent,
      batches_total: batches_total,
      batches_done: batches_done,
      occ_revc: occ_revc
    }
  end

  private

  def terminal_status?
    %w[succeeded failed].include?(status)
  end

  def broadcast(payload:, kind:)
    ActionCable.server.broadcast(
      CHANNEL,
      {
        id: id,
        kind: kind,
        ts: Time.current.to_i,
        payload: payload
      }
    )
  end

  # Throttling: only allow one broadcast per time window
  def acquire_broadcast_throttle!(window:)
    Rails.cache.write(
      broadcast_throttle_key,
      1,
      expires_in: window,
      unless_exist: true
    )
  rescue => e
    Rails.logger&.error(
      "[ProcessRunBroadcastor] acquire_throttle failed run_id=#{id} err=#{e.class}: #{e.message}"
    )
    false
  end

  def broadcast_throttle_key
    "#{progress_namespace}:broadcast_throttle"
  end

  def read_counter(key)
    Rails.cache.increment(key, 0)
  end
end