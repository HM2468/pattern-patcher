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
  after_commit :enqueue_import_job, on: :create

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

  # 给别处用：返回“真实可用的绝对路径”
  # - dev/test: root_path 本身就是绝对路径
  # - production: ENV[GIT_WORKSPACE_ROOT] + root_path
  def resolved_root_path
    if Rails.env.production?
      Pathname.new(ENV.fetch("GIT_WORKSPACE_ROOT")).join(root_path.to_s).expand_path
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
      # 生产环境：只存相对路径（避免把宿主机绝对路径写入 DB）
      self.root_path = root_path.sub(%r{\A/+}, "")
    else
      # 开发/测试：允许用户填相对路径，但最终存绝对路径更稳
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
    # 开发环境：必须是绝对路径（更明确，避免“我以为是相对路径”的误操作）
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

    # 生产环境：root_path 必须是相对路径（防止把宿主机绝对路径写进 DB）
    rp = Pathname.new(root_path)
    if rp.absolute?
      errors.add(:root_path, "must be a relative path under GIT_WORKSPACE_ROOT in production (e.g. myrepo)")
      return
    end

    base = Pathname.new(workspace).expand_path
    full = base.join(root_path).cleanpath

    # 防目录穿越：root_path = ../../etc
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

  def enqueue_import_job
    RepositoryImportJob.perform_later(id)
  end

  def create_snapshot
    # 注意：create_snapshot 会在 transaction commit 后执行，
    # 此时 git_cli 依赖的 root_path 校验已经通过
    commit_sha = git_cli.current_snapshot
    return if commit_sha.nil?

    repository_snapshots.create!(commit_sha: commit_sha, metadata: {})
  end
end