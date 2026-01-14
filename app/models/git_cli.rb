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

  # --------------------------------------------------
  # add_file(path)
  #
  # shell:
  #   git add -- <path>
  #
  # @param path [String]
  # @return [true]
  # --------------------------------------------------
  def add_file(path)
    ensure_ready!

    path = path.to_s.strip
    raise ArgumentError, "path cannot be blank" if path.empty?

    shell!("git add -- #{shell_escape(path)}")
    true
  end

  # --------------------------------------------------
  # commit(message)
  #
  # shell:
  #   git commit -m "<message>"
  #
  # @param message [String]
  # @return [true]
  # --------------------------------------------------
  def commit(message)
    ensure_ready!

    msg = message.to_s.strip
    raise ArgumentError, "commit message cannot be blank" if msg.empty?

    shell!("git commit -m #{shell_escape_double_quoted(msg)}")
    true
  end

  # --------------------------------------------------
  # commit_file(message, file_path)
  #
  # shell:
  #   git commit -m "<message>" -- <file_path>
  #
  # Commits ONLY the staged changes of the given file_path.
  # Other staged files remain staged for later commits.
  #
  # @param message [String]
  # @param file_path [String]
  # @return [true]
  # --------------------------------------------------
  def commit_file(message, file_path, no_verify: false)
    ensure_ready!

    msg = message.to_s.strip
    raise ArgumentError, "commit message cannot be blank" if msg.empty?

    path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if path.empty?

    nv = no_verify ? " --no-verify" : ""
    shell!("git commit#{nv} -m #{shell_escape_double_quoted(msg)} -- #{shell_escape(path)}")
    true
  end

  # --------------------------------------------------
  # has_changes?
  #
  # shell:
  #   git diff --cached --quiet
  #
  # @return [Boolean] true if index has staged changes
  # --------------------------------------------------
  def has_changes?
    ensure_ready!
    diff_cached_quiet? ? false : true
  end

  # --------------------------------------------------
  # has_changes_for_path?(file_path)
  #
  # shell:
  #   git diff --cached --quiet -- <file_path>
  #
  # exit status:
  #   0 => no diff for this path
  #   1 => has diff for this path
  #
  # @return [Boolean]
  # --------------------------------------------------
  def has_changes_for_path?(file_path)
    ensure_ready!

    path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if path.empty?

    command = "git diff --cached --quiet -- #{shell_escape(path)}"
    logger&.debug { "[GitCli] #{root_path}$ #{command}" }

    Timeout.timeout(timeout_seconds) do
      _stdout, stderr, status = Open3.capture3(command, chdir: root_path)

      return true if status.exitstatus == 1
      return false if status.exitstatus == 0

      raise RuntimeError, <<~MSG
        command failed (exit=#{status.exitstatus})
        cwd: #{root_path}
        cmd: #{command}
        stderr: #{stderr.strip}
      MSG
    end
  rescue Timeout::Error
    raise Timeout::Error, "command timeout after #{timeout_seconds}s: #{command}"
  end

  # === awk semantic clone ===
  def list_blob_paths(ref: "HEAD", exts: nil)
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    exts = normalize_exts(exts)

    awk_script =
      if exts.empty?
        "{print $3, $4}"
      else
        pattern = exts.join("|")
        %Q{$4 ~ /\\.(#{pattern})$/ {print $3, $4}}
      end

    command = <<~SH.strip
      git ls-tree -r #{shell_escape(ref)} | awk '#{awk_script}'
    SH

    output = shell!(command)
    parse_awk_output(output)
  end

  def current_snapshot(ref: "HEAD")
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    output = shell!("git rev-parse #{shell_escape(ref)}")
    output.to_s.strip
  end

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

  def read_file(blob)
    ensure_ready!

    blob = blob.to_s.strip
    raise ArgumentError, "blob cannot be blank" if blob.empty?

    unless blob.match?(/\A[0-9a-f]{7,64}\z/i)
      raise ArgumentError, "invalid blob sha format: #{blob.inspect}"
    end

    shell!("git cat-file -p #{shell_escape(blob)}")
  end

  def ready?
    valid?
  end

  private

  # escape for double-quoted shell string: " ... "
  def shell_escape_double_quoted(str)
    %("#{str.to_s.gsub("\\", "\\\\").gsub('"', '\"')}")
  end

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

  def normalize_exts(exts)
    Array(exts)
      .map { |e| e.to_s.strip.sub(/\A\./, "").downcase }
      .reject(&:empty?)
      .uniq
  end

  def shell!(command)
    logger&.debug { "[GitCli] #{root_path}$ #{command}" }

    stdout = +""
    stderr = +""

    Timeout.timeout(timeout_seconds) do
      stdout, stderr, status = Open3.capture3(command, chdir: root_path)

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

  def diff_cached_quiet?
    command = "git diff --cached --quiet"
    logger&.debug { "[GitCli] #{root_path}$ #{command}" }

    Timeout.timeout(timeout_seconds) do
      _stdout, stderr, status = Open3.capture3(command, chdir: root_path)
      return true if status.exitstatus == 0
      return false if status.exitstatus == 1

      raise RuntimeError, <<~MSG
        command failed (exit=#{status.exitstatus})
        cwd: #{root_path}
        cmd: #{command}
        stderr: #{stderr.strip}
      MSG
    end
  rescue Timeout::Error
    raise Timeout::Error, "command timeout after #{timeout_seconds}s: #{command}"
  end

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

  def shell_escape(str)
    str.gsub("'", %q('\''))
  end
end