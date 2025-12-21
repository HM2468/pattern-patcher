module ApplicationHelper
  def stylesheet_link_tag_all
    # Get all CSS files from the stylesheets directory
    css_files = Dir.glob(Rails.root.join('app', 'assets', 'stylesheets', '*.css')).map do |file|
      File.basename(file, '.css')
    end

    # Generate stylesheet_link_tag for each file
    css_files.map do |file_name|
      stylesheet_link_tag(file_name, 'data-turbo-track': 'reload')
    end.join.html_safe
  end
end
