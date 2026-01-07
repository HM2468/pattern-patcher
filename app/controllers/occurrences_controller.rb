class OccurrencesController < ApplicationController
  include ProcessorWorkspaceContext
  layout "processor_workspace", only: %i[index show]

  def index
    @status = params[:status].presence
    base = Occurrence.order(created_at: :desc)

    @occurrences =
      case @status
      when "unprocessed" then base.unprocessed
      when "processed"   then base.processed
      when "ignored" then base.ignored
      else
        base
      end.page(params[:page]).per(10)
  end

  def show; end
end
