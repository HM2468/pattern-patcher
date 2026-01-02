class OccurrenceReviewsController < ApplicationController
  before_action :set_occurrence_review, only: %i[ show edit update destroy ]

  # GET /occurrence_reviews or /occurrence_reviews.json
  def index
    @occurrence_reviews = OccurrenceReview.all
      .includes(:occurrence)
      .order(created_at: :desc)
      .page(params[:page])
      .per(20)
  end

  # GET /occurrence_reviews/1 or /occurrence_reviews/1.json
  def show
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

    # Only allow a list of trusted parameters through.
    def occurrence_review_params
      params.expect(occurrence_review: [ :rendered_code, :status, :apply_status, :metadata ])
    end
end
