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
        .per(15)
  end

  def show
    @occurrence = Occurrence.find(params[:id])
    @file = @occurrence.repository_file
    @repo = @file.repository

    raw_content = @repo.git_cli.read_file(@file.blob_sha).to_s
    raw_lines = raw_content.lines.map { |l| l.chomp("\n").chomp("\r") }

    idx = [@occurrence.line_at.to_i - 1, 0].max
    idx = [idx, raw_lines.length - 1].min if raw_lines.any?
    old_line_from_blob = raw_lines[idx].to_s

    old_line_highlighted =
      if @occurrence.line_char_start && @occurrence.line_char_end
        @occurrence.context = old_line_from_blob if @occurrence.respond_to?(:context=)
        @occurrence.highlighted_deletion.to_s
      else
        ERB::Util.html_escape(old_line_from_blob)
      end

    @diff = GithubLikeDiff.new(
      path: @file.path,
      raw_lines: raw_lines,
      target_lineno: @occurrence.line_at,
      old_line_override: old_line_highlighted,
      new_line: nil,
      context_lines: 3
    )
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