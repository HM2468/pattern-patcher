# frozen_string_literal: true
# app/models/repository.rb

class Repository < ApplicationRecord
  has_many :repository_files
  has_many :repository_snapshots

  validates :name, presence: true
  validates :root_path, presence: true, uniqueness: true
  validates :permitted_ext, presence: true

  validate :validate_root_path_for_env
  before_validation :normalize_inputs

  after_commit :create_snapshot, on: :create

  def git_cli
    @git_cli ||= GitCli.new(self)
  end

  def permitted_extensions
    return [] if permitted_ext.to_s.strip.empty?

    permitted_ext.to_s
      .split(",")
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  def current_snapshot
    repository_snapshots.order(created_at: :desc).first
  end

  # For use elsewhere: returns the actual usable absolute path
  # - dev/test: root_path itself is already an absolute path
  # - production: ENV[GIT_WORKSPACE_ROOT] + root_path
  def resolved_root_path
    if Rails.env.production?
      base = Pathname.new(ENV.fetch("GIT_WORKSPACE_ROOT")).expand_path
      base.join(root_path.to_s).cleanpath.expand_path
    else
      Pathname.new(root_path.to_s).expand_path
    end
  end

  private

  def normalize_inputs
    self.name = name.to_s.strip
    self.root_path = root_path.to_s.strip
    self.permitted_ext = permitted_ext.to_s.strip

    return if root_path.blank?

    if Rails.env.production?
      # Production: store only relative paths (avoid persisting host absolute paths in DB)
      self.root_path = root_path.sub(%r{\A/+}, "")
    else
      # Development/Test: allow relative input, but persist absolute paths for stability
      self.root_path = File.expand_path(root_path)
    end
  end

  def validate_root_path_for_env
    return if root_path.blank?

    if Rails.env.production?
      validate_root_path_for_production!
    else
      validate_root_path_for_development!
    end
  end

  def validate_root_path_for_development!
    # Development/Test: must be an absolute path
    pn = Pathname.new(root_path)

    unless pn.absolute?
      errors.add(:root_path, "must be an absolute path in development/test (e.g. /Users/xxx/repos/myrepo)")
      return
    end

    pn = pn.expand_path
    unless pn.directory?
      errors.add(:root_path, "does not exist: #{pn}")
      return
    end

    unless pn.join(".git").directory?
      errors.add(:root_path, "is not a git repository: #{pn} (missing .git/)")
      return
    end
  end

  def validate_root_path_for_production!
    workspace = ENV["GIT_WORKSPACE_ROOT"].to_s
    if workspace.empty?
      errors.add(:base, "GIT_WORKSPACE_ROOT is not set (required in production)")
      return
    end

    # Production: root_path must be a relative path
    rp = Pathname.new(root_path)
    if rp.absolute?
      errors.add(:root_path, "must be a relative path under GIT_WORKSPACE_ROOT in production (e.g. gitee)")
      return
    end

    base = Pathname.new(workspace).expand_path
    full = base.join(root_path).cleanpath

    # Prevent directory traversal: root_path = ../../etc
    unless full.to_s.start_with?(base.to_s + File::SEPARATOR) || full == base
      errors.add(:root_path, "is invalid (path traversal detected)")
      return
    end

    unless full.directory?
      errors.add(:root_path, "does not exist under workspace: #{full}")
      return
    end

    unless full.join(".git").directory?
      errors.add(:root_path, "is not a git repository under workspace: #{full} (missing .git/)")
      return
    end
  end

  def create_snapshot
    # Executed after the transaction is committed
    commit_sha = git_cli.current_snapshot
    return if commit_sha.nil? || commit_sha.empty?

    repository_snapshots.create!(commit_sha: commit_sha, metadata: {})
  end
end