# frozen_string_literal: true

require "pathname"
require "yaml"
require "json"

module FileUtilConcern
  module_function

  # Recursively list file paths under dir_path.
  #
  # @param dir_path [String] root directory
  # @param pattern [String] glob pattern, e.g. "*" / "*.rb" / "**/*.yml"
  # @param sort [Boolean] whether to sort results
  # @param relative [Boolean] whether to return paths relative to dir_path
  # @return [Array<String>]
  def list_files(dir_path, pattern: "*", sort: true, relative: false)
    root = Pathname.new(dir_path)

    # Ruby's Dir.glob supports recursive patterns via "**".
    # We mimic Python rglob(pattern) by always searching under root recursively.
    glob = root.join("**", pattern).to_s

    files = Dir.glob(glob, File::FNM_CASEFOLD).select { |p| File.file?(p) }.map do |p|
      pn = Pathname.new(p)
      relative ? pn.relative_path_from(root).to_s : pn.to_s
    end

    sort ? files.sort : files
  end

  # Load a YAML file into a Ruby Hash (or Array, depending on YAML content).
  #
  # @param path [String, Pathname]
  # @return [Object]
  def load_yml(path)
    file_path = Pathname.new(path.to_s)
    YAML.safe_load(
      file_path.read(encoding: "UTF-8"),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false
    )
  end

  # Load a JSON file into a Ruby Hash/Array.
  #
  # @param path [String, Pathname]
  # @return [Object]
  def load_json(path)
    file_path = Pathname.new(path.to_s)
    JSON.parse(file_path.read(encoding: "UTF-8"))
  end

  # Read a plain text file.
  #
  # @param path [String, Pathname]
  # @return [String]
  def load_plain(path)
    file_path = Pathname.new(path.to_s)
    file_path.read(encoding: "UTF-8")
  end

  # Read a file line by line, normalize line breaks, strip trailing spaces/tabs,
  # and drop empty/whitespace-only lines.
  #
  # @param path [String, Pathname]
  # @return [Array<String>]
  def read_lines(path)
    file_path = Pathname.new(path.to_s)
    content = file_path.read(encoding: "UTF-8")

    # Normalize line breaks and <br> tags to "\n"
    content = content.gsub(/\r\n?/, "\n")
                     .gsub(%r{</?br/?>}i, "\n")

    content.each_line.map { |line| line.rstrip } # rstrip removes trailing whitespace incl. spaces/tabs/newlines
           .reject { |line| line.strip.empty? }
  end

  # Write plain text file (UTF-8).
  #
  # @param content [String]
  # @param path [String, Pathname]
  # @return [void]
  def write_plain(content, path)
    file_path = Pathname.new(path.to_s)
    file_path.write(content, encoding: "UTF-8")
  end

  # Write YAML file. Preserves insertion order unless sorting is requested.
  #
  # @param data [Hash]
  # @param path [String, Pathname]
  # @param sorted_keys [Boolean]
  # @param sort_by_value_len [Boolean]
  # @return [void]
  def write_yml(data, path, sorted_keys: false, sort_by_value_len: false)
    file_path = Pathname.new(path.to_s)
    processed = process_hash(data, sort_keys: sorted_keys, sort_by_val_len: sort_by_value_len)

    # YAML.dump keeps Ruby Hash order; no implicit sort unless you sort yourself.
    file_path.write(YAML.dump(processed), encoding: "UTF-8")
  end

  # Write JSON file. Preserves insertion order unless sorting is requested.
  #
  # @param data [Hash]
  # @param path [String, Pathname]
  # @param sorted_keys [Boolean]
  # @param sort_by_value_len [Boolean]
  # @return [void]
  def write_json(data, path, sorted_keys: false, sort_by_value_len: false)
    file_path = Pathname.new(path.to_s)
    processed = process_hash(data, sort_keys: sorted_keys, sort_by_val_len: sort_by_value_len)

    # JSON.pretty_generate preserves insertion order from the Hash.
    file_path.write(JSON.pretty_generate(processed), encoding: "UTF-8")
  end

  # Get file extension (lowercased), including the dot, e.g. ".yml"
  #
  # @param path [String]
  # @return [String]
  def get_file_ext(path)
    Pathname.new(path).extname.downcase
  end

  # --------------------
  # internal helpers
  # --------------------

  def process_hash(data, sort_keys: false, sort_by_val_len: false)
    raise ArgumentError, "data must be a Hash" unless data.is_a?(Hash)

    if sort_by_val_len
      data.sort_by { |k, v| v.to_s.length }.to_h
    elsif sort_keys
      data.sort_by { |k, _v| k.to_s }.to_h
    else
      data
    end
  end

  private_class_method :process_hash
end