# app/controllers/occurrences_controller.rb
class OccurrencesController < ApplicationController
  include RepositoryWorkspaceContext

  layout "repository_workspace", only: %i[index show]

  before_action :set_scan_run, only: %i[index]
  before_action :set_status,   only: %i[index]

  def index
    base = base_scope
    scoped =
      case @status
      when "unprocessed" then base.unprocessed
      when "processed"   then base.processed
      when "ignored"     then base.ignored
      else
        base
      end
    @occurrences =
      scoped
        .includes(:repository_file)
        .order(:repository_file_id, :line_at, :line_char_start, :id)
        .page(params[:page])
        .per(10)
  end

  def show
  end

  private

  def set_scan_run
    scan_run_id = params[:scan_run_id].presence
    @scan_run = scan_run_id ? ScanRun.find_by(id: scan_run_id) : nil
  end

  def set_status
    @status = params[:status].presence
  end

  def base_scope
    @scan_run ? @scan_run.occurrences : Occurrence.all
  end
end