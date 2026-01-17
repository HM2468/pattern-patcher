class WikiController < ApplicationController
  layout "wiki_workspace", only: %i[show]

  WIKI_ROOT = Rails.root.join("docs").freeze

  def show
    rel  = (params[:path].presence || "overview").to_s
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
