# frozen_string_literal: true
# app/models/git_cli.rb

class GitCli
  include ActiveModel::Model

  require "open3"
  require "timeout"

  attr_reader :repository, :timeout_seconds, :logger, :root_path

  validates :repository, presence: true
  validate :root_path_must_be_valid

  def initialize(repository, timeout_seconds: 20, logger: nil)
    @timeout_seconds = timeout_seconds.to_i
    @logger = logger || (defined?(Rails) ? Rails.logger : nil)
    @repository = repository

    @root_path = repository&.resolved_root_path&.to_s.to_s
  end

  # git add -- <path>
  def add_file(path)
    ensure_ready!
    path = path.to_s.strip
    raise ArgumentError, "path cannot be blank" if path.empty?

    run_git!("add", "--", path)
    true
  end

  # git commit -m "<message>"
  def commit(message)
    ensure_ready!
    msg = message.to_s.strip
    raise ArgumentError, "commit message cannot be blank" if msg.empty?

    run_git!("commit", "-m", msg)
    true
  end


  # git commit -m "<message>" [--no-verify] -- <file_path>
  def commit_file(message, file_path, no_verify: false)
    ensure_ready!

    msg = message.to_s.strip
    raise ArgumentError, "commit message cannot be blank" if msg.empty?

    path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if path.empty?

    argv = ["commit"]
    argv << "--no-verify" if no_verify
    argv += ["-m", msg, "--", path]
    run_git!(*argv)
    true
  end


  # git diff --cached --quiet
  def has_changes?
    ensure_ready!
    diff_cached_quiet? ? false : true
  end


  # git diff --cached --quiet -- <file_path>
  # exit status:
  #   0 => no diff for this path
  #   1 => has diff for this path
  def has_changes_for_path?(file_path)
    ensure_ready!

    path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if path.empty?

    ok = run_git_quiet?("diff", "--cached", "--quiet", "--", path)
    return false if ok # 0 => no diff

    # run_git_quiet? returns false when exitstatus==1 (diff exists)
    true
  end


  # list_blob_paths(ref:, exts:)
  # Instead of `git ls-tree ... | awk ...`, parse in Ruby (no shell).
  # Returns: [[sha, path], ...]
  def list_blob_paths(ref: "HEAD", exts: nil)
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    exts = normalize_exts(exts)

    out = run_git!("ls-tree", "-r", ref)

    out
      .to_s
      .lines
      .map(&:strip)
      .reject(&:empty?)
      .map do |line|
        # format: <mode> <type> <sha>\t<path>
        left, path = line.split("\t", 2)
        next if path.nil?

        sha = left.split(/\s+/)[2]
        next if sha.nil?

        if exts.empty?
          [sha, path]
        else
          next unless exts.any? { |e| path.downcase.end_with?(".#{e}") }
          [sha, path]
        end
      end
      .compact
  end


  # git rev-parse <ref>
  def current_snapshot(ref: "HEAD")
    ensure_ready!
    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    run_git!("rev-parse", ref).to_s.strip
  end


  # git ls-tree <ref> -- <file_path>
  # -> returns blob sha or nil
  def current_file_blob(ref: "HEAD", file_path:)
    ensure_ready!

    ref = ref.to_s.strip
    raise ArgumentError, "ref cannot be blank" if ref.empty?

    file_path = file_path.to_s.strip
    raise ArgumentError, "file_path cannot be blank" if file_path.empty?

    out = run_git!("ls-tree", ref, "--", file_path).to_s.strip
    return nil if out.empty?

    # same format: <mode> <type> <sha>\t<path>
    sha = out.split(/\s+/)[2]
    sha&.strip
  end

  # git cat-file -p <blob>
  def read_file(blob)
    ensure_ready!

    blob = blob.to_s.strip
    raise ArgumentError, "blob cannot be blank" if blob.empty?
    unless blob.match?(/\A[0-9a-f]{7,64}\z/i)
      raise ArgumentError, "invalid blob sha format: #{blob.inspect}"
    end

    run_git!("cat-file", "-p", blob)
  end

  def ready?
    valid?
  end

  private

  def ensure_ready!
    raise RuntimeError, "Invalid GitCli: #{errors.full_messages.join(', ')}" unless valid?
  end

  def root_path_must_be_valid
    unless repository.is_a?(Repository)
      errors.add(:repository, "must be a Repository instance")
      return
    end

    if root_path.nil? || root_path.empty?
      errors.add(:base, "resolved root_path is blank")
      return
    end

    unless Dir.exist?(root_path)
      errors.add(:base, "repository root does not exist: #{root_path}")
      return
    end

    git_dot = File.join(root_path, ".git")
    return if File.directory?(git_dot) || File.file?(git_dot)

    errors.add(:base, "#{root_path} is not a git repository root (.git not found)")
  end

  def normalize_exts(exts)
    Array(exts)
      .map { |e| e.to_s.strip.sub(/\A\./, "").downcase }
      .reject(&:empty?)
      .uniq
  end

  # --- Safe runner: NEVER pass a single string to Open3 ---
  def run_git!(*args)
    argv = ["git", *args.map(&:to_s)]
    logger&.debug { "[GitCli] #{root_path}$ #{argv.inspect}" }

    Timeout.timeout(timeout_seconds) do
      stdout, stderr, status = Open3.capture3(*argv, chdir: root_path)
      return stdout if status.success?

      raise RuntimeError, <<~MSG
        command failed (exit=#{status.exitstatus})
        cwd: #{root_path}
        argv: #{argv.inspect}
        stderr: #{stderr.to_s.strip}
      MSG
    end
  rescue Timeout::Error
    raise Timeout::Error, "command timeout after #{timeout_seconds}s: git #{args.join(' ')}"
  end

  # For commands where exitstatus 0/1 is meaningful (like `git diff --quiet`)
  def run_git_quiet?(*args)
    argv = ["git", *args.map(&:to_s)]
    logger&.debug { "[GitCli] #{root_path}$ #{argv.inspect}" }

    Timeout.timeout(timeout_seconds) do
      _stdout, stderr, status = Open3.capture3(*argv, chdir: root_path)

      return true if status.exitstatus == 0
      return false if status.exitstatus == 1

      raise RuntimeError, <<~MSG
        command failed (exit=#{status.exitstatus})
        cwd: #{root_path}
        argv: #{argv.inspect}
        stderr: #{stderr.to_s.strip}
      MSG
    end
  rescue Timeout::Error
    raise Timeout::Error, "command timeout after #{timeout_seconds}s: git #{args.join(' ')}"
  end

  def diff_cached_quiet?
    run_git_quiet?("diff", "--cached", "--quiet")
  end
end