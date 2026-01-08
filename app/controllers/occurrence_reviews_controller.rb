class OccurrenceReviewsController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show]
  before_action :set_occurrence_review, only: %i[edit update destroy]
  before_action :set_occ_rev, only: %i[show]

  def index
    @status = params[:status].presence
    base = OccurrenceReview
      .joins(occurrence: :repository_file)
      .includes(occurrence: { repository_file: :repository })
      .order("repository_files.path ASC, occurrences.byte_start DESC")
    scoped =
      case @status
      when "pending"  then base.pending
      when "reviewed" then base.reviewed
      when "approved" then base.approved
      when "rejected" then base.rejected
      else
        base
      end
    @occurrence_reviews = scoped.page(params[:page]).per(10)
    @diffs_by_review_id = OccurrenceReviewDiffBatch.build(@occurrence_reviews)
  end


  def show
    @occurrence = @occurrence_review.occurrence
    @file = @occurrence.repository_file
    @repo = @file.repository
    raw_content = @repo.git_cli.read_file(@file.blob_sha).to_s
    # GithubLikeDiff 期望 raw_lines 不带 "\n"，这里统一 chomp
    raw_lines = raw_content.lines.map { |l| l.chomp("\n").chomp("\r") }
    idx = [@occurrence.line_at.to_i - 1, 0].max
    idx = [idx, raw_lines.length - 1].min if raw_lines.any?
    old_line_from_blob = raw_lines[idx].to_s
    # 用「blob 的真实 old_line」按 char range 生成 new_line（更稳）
    new_line =
      if @occurrence_review.rendered_code.present? && @occurrence.line_char_start && @occurrence.line_char_end
        s = @occurrence.line_char_start.to_i
        e = @occurrence.line_char_end.to_i
        # 防御：range 越界时不要炸
        if s >= 0 && e >= s && s <= old_line_from_blob.length
          prefix = old_line_from_blob[0...s].to_s
          suffix = old_line_from_blob[(e + 1)..].to_s
          prefix + @occurrence_review.rendered_code.to_s + suffix
        else
          # fallback：用 snapshot 的替换结果（至少能展示）
          @occurrence.replaced_text.to_s
        end
      else
        # 没有变更就用原行
        old_line_from_blob
      end

    @diff = GithubLikeDiff.new(
      path: @file.path,
      raw_lines: raw_lines,
      target_lineno: @occurrence.line_at,
      old_line_override: old_line_from_blob,
      new_line: new_line,
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

    # Only allow a list of trusted parameters through.
    def occurrence_review_params
      params.expect(occurrence_review: [ :rendered_code, :status, :apply_status, :metadata ])
    end
end
