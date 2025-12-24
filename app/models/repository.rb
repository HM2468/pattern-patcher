# app/models/repository.rb
class Repository < ApplicationRecord
  has_many :repository_files, dependent: :delete_all
  has_many :repository_snapshots, dependent: :delete_all

  validates :name, presence: true
  validates :root_path, presence: true, uniqueness: true
  validates :permitted_ext, presence: true

  before_validation :normalize_inputs
  before_save :check_root_path_exists
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

  private

  def normalize_inputs
    self.name = name.to_s.strip
    self.root_path = root_path.to_s.strip
    self.permitted_ext = permitted_ext.to_s.strip
  end

  def check_root_path_exists
    Dir.exist?(root_path) || errors.add(:root_path, "does not exist: #{root_path}")
  end

  def enqueue_import_job
    RepositoryImportJob.perform_later(id)
  end

  def create_snapshot
    commit_sha = git_cli.current_snapshot
    return if commit_sha.nil?

    repository_snapshots.create!(commit_sha: commit_sha, metadata: {})
  end
end