class OccurrenceReviewsController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show]
  before_action :set_occurrence_review, only: %i[edit update destroy]
  before_action :set_occ_rev, only: %i[show approve reject]

  def index
    @status = params[:status].presence
    @text_filter = params[:text_filter].to_s.strip
    @path_filter = params[:path_filter].to_s.strip

    @pending_count = OccurrenceReview.pending.count
    @rejected_count = OccurrenceReview.rejected.count

    base = OccurrenceReview
      .joins(occurrence: :repository_file)
      .includes(occurrence: { repository_file: :repository })
      .order("repository_files.path ASC, occurrences.byte_start DESC")

    scoped =
      case @status
      when "pending"  then base.pending
      when "approved" then base.approved
      when "rejected" then base.rejected
      else
        base.pending
      end

    if @text_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@text_filter)
      scoped = scoped.where("occurrences.matched_text ILIKE ?", "%#{escaped}%")
    end

    if @path_filter.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@path_filter)
      scoped = scoped.where("repository_files.path ILIKE ?", "%#{escaped}%")
    end

    @occurrence_reviews = scoped.page(params[:page]).per(10)
    @diffs_by_review_id = DiffBatch.build(@occurrence_reviews)
  end

  def show
    @occurrence = @occurrence_review.occurrence
    @file = @occurrence.repository_file
    @repo = @file.repository

    raw_content = @repo.git_cli.read_file(@file.blob_sha).to_s
    raw_lines = raw_content.lines.map { |l| l.chomp("\n").chomp("\r") }

    idx = [@occurrence.line_at.to_i - 1, 0].max
    idx = [idx, raw_lines.length - 1].min if raw_lines.any?
    old_line_from_blob = raw_lines[idx].to_s

    # 用 blob 的真实 old_line 构建“带高亮”的 old/new 行
    old_line_highlighted =
      if @occurrence.line_char_start && @occurrence.line_char_end
        # 用 blob 行覆盖 occurrence.context，确保 char range 对齐
        @occurrence.context = old_line_from_blob if @occurrence.respond_to?(:context=)
        @occurrence.highlighted_deletion.to_s
      else
        ERB::Util.html_escape(old_line_from_blob)
      end

    new_line_highlighted =
      if @occurrence_review.rendered_code.present? && @occurrence.line_char_start && @occurrence.line_char_end
        @occurrence.context = old_line_from_blob if @occurrence.respond_to?(:context=)
        @occurrence.occurrence_review = @occurrence_review if @occurrence.respond_to?(:occurrence_review=)
        @occurrence.highlighted_addition.to_s
      else
        ERB::Util.html_escape(old_line_from_blob)
      end

    @diff = GithubLikeDiff.new(
      path: @file.path,
      raw_lines: raw_lines,
      target_lineno: @occurrence.line_at,
      old_line_override: old_line_highlighted,
      new_line: new_line_highlighted,
      context_lines: 3
    )
  end

  # GET /occurrence_reviews/new
  def new
    @occurrence_review = OccurrenceReview.new
  end

  # GET /occurrence_reviews/1/edit
  def edit
  end

  # POST /occurrence_reviews or /occurrence_reviews.json
  def create
    @occurrence_review = OccurrenceReview.new(occurrence_review_params)

    respond_to do |format|
      if @occurrence_review.save
        format.html { redirect_to @occurrence_review, notice: "Occurrence review was successfully created." }
        format.json { render :show, status: :created, location: @occurrence_review }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @occurrence_review.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /occurrence_reviews/1 or /occurrence_reviews/1.json
  def update
    respond_to do |format|
      if @occurrence_review.update(occurrence_review_params)
        format.html { redirect_to @occurrence_review, notice: "Occurrence review was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @occurrence_review }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @occurrence_review.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /occurrence_reviews/1 or /occurrence_reviews/1.json
  def destroy
    @occurrence_review.destroy!

    respond_to do |format|
      format.html { redirect_to occurrence_reviews_path, notice: "Occurrence review was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def approve
    @occurrence_review.update!(status: "approved")
    flash[:success] = "Code change was successfully applied."
    redirect_to occurrence_reviews_path(forwarded_params)
  end

  def reject
    @occurrence_review.update!(status: "rejected")
    flash[:alert] = "Code change was rejected."
    redirect_to occurrence_reviews_path(forwarded_params)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_occurrence_review
      @occurrence_review = OccurrenceReview.find(params.expect(:id))
    end

    def set_occ_rev
      @occurrence_review =
        OccurrenceReview
          .includes(occurrence: { repository_file: :repository })
          .find(params[:id])
    end

    def forwarded_params
      {
        page: params[:page].presence,
        status: params[:status].presence,
        filter_type: params[:filter_type].presence,
        text_filter: params[:text_filter].presence,
        path_filter: params[:path_filter].presence,
      }.compact
    end

    # Only allow a list of trusted parameters through.
    def occurrence_review_params
      params.expect(occurrence_review: [ :rendered_code, :status, :apply_status, :metadata ])
    end
end
