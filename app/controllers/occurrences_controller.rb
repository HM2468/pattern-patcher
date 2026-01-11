# app/controllers/occurrences_controller.rb
class OccurrencesController < ApplicationController
  include RepositoryWorkspaceContext
  layout "repository_workspace", only: %i[index show]

  before_action :set_scan_run, only: %i[index]
  before_action :set_status,   only: %i[index]

  def index
    @text_filter = params[:text_filter].to_s.strip
    @path_filter = params[:path_filter].to_s.strip

    # counts(与 OccurrenceReviewsController 一样：不受搜索影响；受 scan_run_id 影响)
    count_scope = base_scope
    @unprocessed_count = count_scope.unprocessed.count
    @processed_count   = count_scope.processed.count
    @ignored_count     = count_scope.ignored.count

    # base(joins + includes + order)
    base = base_scope
      .joins(:repository_file)
      .includes(repository_file: :repository)
      .order("repository_files.path ASC, occurrences.byte_start DESC")

    # status filter(默认 unprocessed)
    scoped =
      case @status
      when "unprocessed" then base.unprocessed
      when "processed"   then base.processed
      when "ignored"     then base.ignored
      else
        base.unprocessed
      end

    # text_filter (occurrences.matched_text)
    if @text_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@text_filter)
      scoped = scoped.where("occurrences.matched_text ILIKE ?", "%#{escaped}%")
    end

    # path_filter (repository_files.path)
    if @path_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@path_filter)
      scoped = scoped.where("repository_files.path ILIKE ?", "%#{escaped}%")
    end

    @occurrences = scoped.page(params[:page]).per(15)

    @diffs_by_occurrence_id = DiffBatch.build(@occurrences)
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