# frozen_string_literal: true
# app/models/git_cli.rb

class GitCli
  include ActiveModel::Model

  require "open3"
  require "timeout"

  attr_reader :repository, :timeout_seconds, :logger, :root_path

  validates :repository, presence: true

  def initialize(repository, timeout_seconds: 20, logger: nil)
    @timeout_seconds = timeout_seconds.to_i
    @logger = logger || (defined?(Rails) ? Rails.logger : nil)

    unless repository.is_a?(Repository)
      errors.add(:repository, "must be a Repository instance")
      return
    end

    @repository = repository
    @root_path  = File.expand_path(repository.root_path.to_s)

    validate_root_path!
  rescue => e
    errors.add(:base, e.message)
  end

  # === awk semantic clone ===
  #
  # with exts:
  #   git ls-tree -r <ref> | awk '$4 ~ /\.(rb|haml)$/ {print $3, $4}'
  #
  # without exts:
  #   git ls-tree -r <ref> | awk '{print $3, $4}'
  #
  # @param ref  [String] branch / tag / commit
  # @param exts [Array<String>, nil, ""] file extensions
  # @return [Array<[String, String]>] [[blob_sha, path], ...]
  #
  def list_blob_paths(ref: "HEAD", exts: nil)
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    exts = normalize_exts(exts)

    awk_script =
      if exts.empty?
        # no filter
        "{print $3, $4}"
      else
        # /\.(rb|haml)$/
        pattern = exts.join("|")
        %Q{$4 ~ /\\.(#{pattern})$/ {print $3, $4}}
      end

    command = <<~SH.strip
      git ls-tree -r #{shell_escape(ref)} | awk '#{awk_script}'
    SH

    output = shell!(command)
    parse_awk_output(output)
  end

  # --------------------------------------------------
  # current_snapshot(ref: 'HEAD')
  #
  # shell:
  #   git rev-parse HEAD
  #
  # @param ref [String]
  # @return [String] full commit sha
  # --------------------------------------------------
  def current_snapshot(ref: "HEAD")
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    output = shell!("git rev-parse #{shell_escape(ref)}")
    output.to_s.strip
  end

  # --------------------------------------------------
  # current_file_blob(ref: 'HEAD', file_path:)
  #
  # shell:
  #   git ls-tree HEAD app/models/repository.rb | awk '{print $3}'
  #
  # @param ref [String]
  # @param file_path [String]
  # @return [String, nil] blob sha or nil if file not found
  # --------------------------------------------------
  def current_file_blob(ref: "HEAD", file_path:)
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    file_path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if file_path.empty?

    command = <<~SH.strip
      git ls-tree #{shell_escape(ref)} #{shell_escape(file_path)} | awk '{print $3}'
    SH

    output = shell!(command).to_s.strip
    output.empty? ? nil : output
  end

  # --------------------------------------------------
  # read_file(blob)
  #
  # shell:
  #   git cat-file -p <blob_sha>
  #
  # @param blob [String] git blob sha
  # @return [String] file content
  # --------------------------------------------------
  def read_file(blob)
    ensure_ready!

    blob = blob.to_s.strip
    raise ArgumentError, "blob cannot be blank" if blob.empty?

    # Optional sanity check: keep it simple but catch obvious junk early.
    unless blob.match?(/\A[0-9a-f]{7,64}\z/i)
      raise ArgumentError, "invalid blob sha format: #{blob.inspect}"
    end

    shell!("git cat-file -p #{shell_escape(blob)}")
  end

  def ready?
    valid?
  end

  private

  # -------------------------
  # guards / validation
  # -------------------------

  def ensure_ready!
    raise RuntimeError, "Invalid GitCli: #{errors.full_messages.join(', ')}" unless valid?
  end

  def validate_root_path!
    raise ArgumentError, "repository.root_path is blank" if root_path.nil? || root_path.empty?
    raise ArgumentError, "repository.root_path does not exist: #{root_path}" unless Dir.exist?(root_path)

    git_dot = File.join(root_path, ".git")
    return if File.directory?(git_dot) || File.file?(git_dot)

    raise ArgumentError, "#{root_path} is not a git repository root (.git not found)"
  end

  # normalize extensions
  # nil, "", [] => []
  def normalize_exts(exts)
    Array(exts)
      .map { |e| e.to_s.strip.sub(/\A\./, "").downcase }
      .reject(&:empty?)
      .uniq
  end

  # -------------------------
  # shell execution
  # -------------------------

  def shell!(command)
    logger&.debug { "[GitCli] #{root_path}$ #{command}" }

    stdout = +""
    stderr = +""

    Timeout.timeout(timeout_seconds) do
      stdout, stderr, status =
        Open3.capture3(command, chdir: root_path)

      unless status.success?
        raise RuntimeError, <<~MSG
          command failed (exit=#{status.exitstatus})
          cwd: #{root_path}
          cmd: #{command}
          stderr: #{stderr.strip}
        MSG
      end
    end

    stdout
  rescue Timeout::Error
    raise Timeout::Error, "command timeout after #{timeout_seconds}s: #{command}"
  end

  # -------------------------
  # parsing
  # -------------------------

  # awk prints: "<sha> <path>"
  def parse_awk_output(output)
    output
      .to_s
      .lines
      .map(&:strip)
      .reject(&:empty?)
      .map do |line|
        sha, path = line.split(/\s+/, 2)
        [sha, path]
      end
  end

  # minimal shell escaping for ref / path / sha
  #
  # NOTE: This is intentionally minimal and assumes we only pass safe-ish tokens
  # (refs, paths, SHAs). If you later accept arbitrary strings, switch to
  # Open3.capture3(*argv) style and avoid the shell entirely.
  def shell_escape(str)
    str.gsub("'", %q('\''))
  end
end