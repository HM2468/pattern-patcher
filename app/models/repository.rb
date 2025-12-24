# app/models/repository.rb
class Repository < ApplicationRecord
  has_many :repository_files, dependent: :delete_all

  validates :name, presence: true
  validates :root_path, presence: true, uniqueness: true
  validates :permitted_ext, presence: true

  before_validation :normalize_inputs
  after_commit :enqueue_import_job, on: :create

  def git_cli
    @git_cli ||= GitCli.new(self)
  end

  def permitted_extensions
    permitted_ext.to_s
      .split(",")
      .map(&:strip)
      .reject(&:blank?)
      .map { |e| e.start_with?(".") ? e.downcase : ".#{e.downcase}" }
      .uniq
  end

  private

  def normalize_inputs
    self.name = name.to_s.strip
    self.root_path = root_path.to_s.strip
    self.permitted_ext = permitted_ext.to_s.strip
  end

  def enqueue_import_job
    RepositoryImportJob.perform_later(id)
  end
end