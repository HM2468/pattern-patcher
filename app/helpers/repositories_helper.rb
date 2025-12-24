module RepositoriesHelper
  def init_scan_hint_message
    @current_pattern = LexicalPattern.current_pattern
    if @current_pattern.nil?
      @scan_hint_message = @scan_all_hint =
        "No enabled pattern found. Please set up one in
          <a href='#{lexical_patterns_path}' class='underline'>Lexical Patterns</a> page."
    else
      @scan_hint_message =
          "Scan selected files with pattern: <strong>#{@current_pattern.name}</strong>?
            Or change <a href='#{lexical_patterns_path}' class='underline'>current pattern</a>."
      @scan_all_hint =
          "Scan all files in <strong>#{@current_repo.name}</strong> with pattern: <strong>#{@current_pattern.name}</strong>?
            Or change <a href='#{lexical_patterns_path}' class='underline'>current pattern</a>."
    end
  end
end
