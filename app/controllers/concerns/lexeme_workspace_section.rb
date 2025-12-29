# frozen_string_literal: true

# app/controllers/concerns/lexeme_workspace_section.rb
module LexemeWorkspaceSection
  extend ActiveSupport::Concern

  included do
    before_action :set_processor_nav
    layout "lexeme_workspace"

    # 让 layout / view 里也能直接调用 nav_selections
    helper_method :nav_selections, :lexeme_workspace_section
  end

  private

  # 单一真源：label, section_key, route_helper
  def lexeme_workspace_nav
    [
      ["Processors",   "processors",   :lexeme_processors_path],
      ["Process Jobs", "process_jobs", :lexeme_process_jobs_path],
      ["Lexemes",      "lexemes",      :lexemes_path]
    ]
  end

  # 给 layout 用：返回当前 section
  def lexeme_workspace_section
    @section.presence || "processors"
  end

  # 给 layout 用：返回带 url 的三元组
  # [
  #   ["Processors", "processors", "/lexeme_processors"],
  #   ["Process Jobs", "process_jobs", "/lexeme_process_jobs"],
  #   ["Lexemes", "lexemes", "/lexemes"]
  # ]
  def nav_selections
    lexeme_workspace_nav.map do |label, key, route_helper|
      [label, key, public_send(route_helper)]
    end
  end

  # controller -> section
  def set_processor_nav
    @section =
      case controller_name
      when "lexeme_processors"   then "processors"
      when "lexeme_process_jobs" then "process_jobs"
      when "lexemes"             then "lexemes"
      else "processors"
      end
  end
end