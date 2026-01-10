class DashboardController < ApplicationController
  layout "manual_workspace", only: %i[index]

  def index
  end
end
