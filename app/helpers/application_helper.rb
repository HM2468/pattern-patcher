# app/helpers/application_helper.rb

module ApplicationHelper

  FLASH_CLASSES = {
    "notice"  => "border-blue-200 bg-blue-50 text-blue-800",
    "info"    => "border-blue-200 bg-blue-50 text-blue-800",
    "success" => "border-green-200 bg-green-50 text-green-800",
    "alert"   => "border-yellow-200 bg-yellow-50 text-yellow-800",
    "warning" => "border-yellow-200 bg-yellow-50 text-yellow-800",
    "error"   => "border-red-200 bg-red-50 text-red-800"
  }.freeze


  def svg_icon(name, class_name: "")
    path = Rails.root.join("app/assets/images/icons/#{name}.svg")
    return "" unless File.exist?(path)

    svg = File.read(path)
    svg.sub("<svg", %(<svg class="#{ERB::Util.html_escape(class_name)}")).html_safe
  end


  # Returns:
  # [
  #   ["Processors", "processors", "/lexeme_processors"],
  #   ["Process Runs", "process_runs", "/process_runs"],
  #   ["Lexemes", "lexemes", "/lexemes"]
  # ]
  def nav_selections
    LexemeWorkspace::NAV.map do |label, key, route_helper|
      [label, key, public_send(route_helper)]
    end
  end

  def flash_css_class(type)
    FLASH_CLASSES[type.to_s] || "border-gray-200 bg-gray-50 text-gray-800"
  end

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

  def new_action?
    action_name == "new"
  end

  def edit_action?
    action_name == "edit"
  end
end
