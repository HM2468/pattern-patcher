class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def render_repo_right(template)
    if turbo_frame_request?
      render template, layout: false
    else
      render template
    end
  end
end
