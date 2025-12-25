# frozen_string_literal: true

class ScanRunsController < ApplicationController
  def index; end
  def show; end

  def create
    @repository = Repository.find_by(id: params[:repository_id])

    unless @repository
      flash[:alert] = "Repository not found."
      return redirect_to(repositories_path)
    end

    scan_pattern = LexicalPattern.current_pattern
    if scan_pattern.nil?
      flash[:alert] = "No enabled pattern found. Please set up one in Lexical Patterns page."
      return redirect_to(repositories_path(repository_id: @repository.id))
    end

    file_ids = params[:file_ids].presence || []

    snapshot = @repository.current_snapshot
    if snapshot.nil?
      flash[:alert] = "No repository snapshot found. Please import the repository first."
      return redirect_to(repositories_path(repository_id: @repository.id))
    end

    @scan_run =
      ScanRun.new(
        lexical_pattern_id: scan_pattern.id,
        repository_snapshot_id: snapshot.id,
        status: "pending",
        started_at: Time.current,
        pattern_snapshot: scan_pattern.pattern,
        cursor: { total: 0, done: 0, failed: 0, started_at: Time.current.iso8601 }
      )

    if @scan_run.save
      flash[:success] = "Scan created and started."
      StartScanJob.perform_later(
        scan_run_id: @scan_run.id,
        repository_id: @repository.id,
        file_ids: file_ids
      )
      redirect_to(scan_runs_path(repository_id: @repository.id))
    else
      flash[:error] = @scan_run.errors.full_messages.join(", ")
      redirect_to(repositories_path(repository_id: @repository.id))
    end
  end
end