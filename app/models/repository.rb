# app/models/repository.rb
class Repository < ApplicationRecord
  has_many :repository_files, dependent: :delete_all

  STATUSES = %w[active disabled].freeze

  validates :name, presence: true
  validates :root_path, presence: true, uniqueness: true
  validates :permitted_ext, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  before_validation :normalize_inputs
  after_commit :enqueue_import_job, on: :create

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
    self.status = (status.presence || "active")
  end

  def enqueue_import_job
    RepositoryImportJob.perform_now(id)
  end
end