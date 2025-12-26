# frozen_string_literal: true

# app/helpers/scan_runs_helper.rb
module ScanRunsHelper
  # One call for scan_run derived display fields
  # Returns:
  # {
  #   repo_name:, sha_short:, lp_name:, occ_count:, bar_class:
  # }
  def scan_run_display(scan_run, sha_length: 7)
    status = scan_run.status.to_s

    {
      repo_name: scan_run.repository_name,
      sha_short: scan_run.commit_sha.to_s[0, sha_length],
      lp_name:   scan_run.lexical_pattern_name,
      occ_count: scan_run.occurrences_count.to_i,
      bar_class: ScanRun::PROGRESS_COLOR[status]
    }
  end

  # One call for progress derived display fields
  # progress supports symbol/string keys
  # Returns:
  # {
  #   phase:, total:, done:, failed:, err_msg:, pct:
  # }
  def scan_run_progress_display(progress)
    phase  = fetch(progress, :phase) || "unknown"
    total  = fetch(progress, :total).to_i
    done   = fetch(progress, :done).to_i
    failed = fetch(progress, :failed).to_i
    err    = fetch(progress, :error)

    pct =
      if total > 0
        [[((done.to_f / total) * 100).round, 0].max, 100].min
      else
        0
      end

    {
      phase: phase,
      total: total,
      done: done,
      failed: failed,
      err_msg: err,
      pct: pct
    }
  end

  private

  def fetch(obj, key)
    return nil if obj.blank?
    obj[key] || obj[key.to_s]
  end
end