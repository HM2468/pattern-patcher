class ScanRunsController < ApplicationController
  def index
  end

  def show
  end

  def create
    scan_pattern = LexicalPattern.current_pattern
    if scan_pattern.nil?
      flash[:alert] = "No enabled pattern found. Please set up one in Lexical Patterns page."
      redirect_to repositories_path(repository_id: params[:repository_id])
    end
    @repository = Repository.find_by(id: params[:repository_id])
    file_ids = params[:file_ids] || @repository.repository_files.pluck(:id)
    file_ids.sort!
    @scan_run = ScanRun.new(
      lexical_pattern_id: scan_pattern.id,
      pattern_snapshot: scan_pattern.pattern,
      started_at: Time.current,
      repository_snapshot_id: @repository.current_snapshot&.id,
      file_ids: file_ids.join(','),
      cursor: { total: file_ids.size, current_idx: 0 }
    )
    if @scan_run.save!
      flash[:success] = "Scan created and stared"
      redirect_to scan_runs_path
    else
      flash[:error] = @scan_run.errors.full_messages.join(',')
      redirect_to scan_runs_path
    end

  end
end
