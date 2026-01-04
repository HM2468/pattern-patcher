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

  # Build data attributes for Stimulus tooltip controller.
  #
  # Usage:
  #   data: tooltip_data(tip: "New Repository")
  #   data: tooltip_data(tip: "Delete", placement: "bottom", confirm_title: "...", confirm_message: "...")
  #   data: tooltip_data(tip: "Edit", controller: "tooltip other-controller", action: "mouseenter->x#y")
  #
  # Notes:
  # - `tip:` is required.
  # - `placement:` defaults to "bottom".
  # - You can pass extra key-values, they will be merged into the data hash.
  # - If you pass `controller:`, it will be appended (not overwritten).
  def tooltip_data(tip:, placement: "bottom", controller: nil, **extra)
    raise ArgumentError, "tooltip_data requires `tip:`" if tip.blank?
    data = {
      tooltip_text_value: tip,
      tooltip_placement_value: placement
    }
    # Allow adding/merging controller(s).
    # - If caller provides controller: "tooltip foo", we keep it.
    # - Otherwise ensure "tooltip" is included.
    controllers = []
    controllers << "tooltip"
    controllers.concat(controller.to_s.split(/\s+/)) if controller.present?
    controllers = controllers.uniq
    data[:controller] = controllers.join(" ")
    # Merge extra data-* attributes (e.g. turbo_frame, action, confirm_title...)
    # NOTE: keys should be snake_case here, Rails will render as data-*
    data.merge!(extra) if extra.present?
    data
  end

  # {
  #   controller: "tooltip",
  #   tooltip_text_value: "Delete",
  #   tooltip_placement_value: "bottom",
  #   confirm_title: "Delete pattern",
  #   confirm_message: "Delete this pattern? This cannot be undone."
  # }
  def delete_tip(title: '', msg: '')
    tooltip_data(tip: 'Delete', confirm_title: title, confirm_message: msg)
  end

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
