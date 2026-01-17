class DashboardController < ApplicationController
  # layout "manual_workspace", only: %i[index]

  WIKI_ROOT = Rails.root.join("docs").freeze

  def index; end

  def show
    rel  = (params[:path].presence || "Home").to_s
    file = WIKI_ROOT.join("#{rel}.md")
    raise ActiveRecord::RecordNotFound unless file.exist?

    markdown = file.read

    doc = Commonmarker.parse(
      markdown,
      options: {
        parse: { smart: true },
        extension: {
          table: true,
          strikethrough: true,
          autolink: true,
          tasklist: true,
          tagfilter: true,
          footnotes: true
        }
      }
    )

    @content_html = doc.to_html(
      options: {
        render: { hardbreaks: false, unsafe: false }
      }
    )
  end



end
