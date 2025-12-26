# app/helpers/scan_runs_helper.rb
module ScanRunsHelper
  # --------
  # Display helpers
  # --------

  def scan_run_repo_name(scan_run)
    scan_run.repository_name
  end

  def scan_run_commit_sha_short(scan_run, length: 7)
    scan_run.commit_sha.to_s[0, length]
  end

  def scan_run_lexical_pattern_name(scan_run)
    scan_run.lexical_pattern_name
  end

  def scan_run_occurrences_count(scan_run)
    scan_run.occurrences_count.to_i
  end

  def scan_run_status(scan_run)
    scan_run.status.to_s
  end

  # --------
  # Progress payload helpers
  # Supports both string/symbol keys
  # --------

  def scan_run_progress_phase(progress)
    fetch_progress(progress, :phase) || "unknown"
  end

  def scan_run_progress_total(progress)
    fetch_progress(progress, :total).to_i
  end

  def scan_run_progress_done(progress)
    fetch_progress(progress, :done).to_i
  end

  def scan_run_progress_failed(progress)
    fetch_progress(progress, :failed).to_i
  end

  def scan_run_progress_error(progress)
    fetch_progress(progress, :error)
  end

  def scan_run_progress_percent(progress)
    total = scan_run_progress_total(progress)
    done  = scan_run_progress_done(progress)

    return 0 if total <= 0

    pct = (done.to_f / total * 100).round
    [[pct, 0].max, 100].min
  end

  # --------
  # UI class helpers
  # --------

  def scan_run_status_bar_class(status)
    case status.to_s
    when "pending"              then "bg-gray-300"
    when "running"              then "bg-indigo-500"
    when "finished"             then "bg-emerald-500"
    when "failed"               then "bg-red-500"
    when "finished_with_errors" then "bg-amber-500"
    else "bg-gray-300"
    end
  end

  private

  def fetch_progress(progress, key)
    return nil if progress.blank?
    progress[key] || progress[key.to_s]
  end
end