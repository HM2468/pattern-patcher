class OccurrenceReviewsController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show]
  before_action :set_occurrence_review, only: %i[ show edit update destroy ]

  def index
    @status = params[:status].presence
    base = OccurrenceReview
      .includes(occurrence: :repository_file).order(created_at: :desc)

    @occurrence_reviews =
      case @status
      when "pending" then base.pending
      when "reviewed"   then base.reviewed
      when "approved" then base.approved
      when "rejected" then base.rejected
      else
        base
      end.page(params[:page]).per(15)
  end

  def show
    @occurrence_review = OccurrenceReview.includes(occurrence: { repository_file: :repository }).find(params[:id])
    @occurrence = @occurrence_review.occurrence
    @file = @occurrence.repository_file
    @repo = @file.repository

    git_cli = @repo.git_cli

    raw_content = git_cli.read_file(@file.blob_sha).to_s
    raw_lines = raw_content.gsub("\r\n", "\n").split("\n", -1) # 保留空行

    # 原行号：occurrence.line_at
    # 替换后行：occurrence.replaced_text（你说就用这个）
    # 但 replaced_text 返回的是整段 context 的“替换后”，如果你的 occurrence.context 是单行，那就刚好；
    # 如果 occurrence.context 是“某一行内容”，也OK；
    # 如果 occurrence.context 是多行片段，你需要只取对应那一行 —— 这里给你一个稳妥处理：
    new_line = extract_new_line_from_occurrence(@occurrence, raw_lines)

    @diff = GithubLikeDiff.new(
      path: @file.path,
      raw_lines: raw_lines,
      target_lineno: @occurrence.line_at,
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

    # 尽量保证 new_line 是“替换后的整行”
    def extract_new_line_from_occurrence(occurrence, raw_lines)
      # 1) 如果你的 occurrence.context 就是该行原始行文本：
      #    replaced_text 也是该行替换后文本
      # 2) 如果 context 可能是多行片段：用 line_char_start/end 与 rendered_code 只替换该行那段
      idx = occurrence.line_at.to_i - 1
      original_line = raw_lines[idx].to_s

      reviewed = occurrence.occurrence_review
      rendered = reviewed&.rendered_code.to_s
      return occurrence.replaced_text.to_s if rendered.blank?

      # 尝试按 char range 仅在该行内替换（最贴近你的设计）
      s = occurrence.line_char_start
      e = occurrence.line_char_end
      return occurrence.replaced_text.to_s if s.nil? || e.nil?

      prefix = original_line[0...s] || ""
      suffix = original_line[(e + 1)..] || ""
      prefix + rendered + suffix
    rescue
      occurrence.replaced_text.to_s
    end


    # Use callbacks to share common setup or constraints between actions.
    def set_occurrence_review
      @occurrence_review = OccurrenceReview.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def occurrence_review_params
      params.expect(occurrence_review: [ :rendered_code, :status, :apply_status, :metadata ])
    end
end
