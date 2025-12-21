# app/models/repository_file.rb
class RepositoryFile < ApplicationRecord
  belongs_to :repository

  has_many :scan_runs, dependent: :destroy
  has_many :occurrences, dependent: :destroy
  has_many :replacement_targets, dependent: :destroy
  has_many :replacement_actions, dependent: :destroy

  validates :path, presence: true
  validates :path, uniqueness: { scope: :repository_id }
  validates :file_sha, length: { is: 64 }, allow_nil: true # sha256 hex

  scope :recently_scanned, -> { order(last_scanned_at: :desc) }
  scope :by_path, -> { order(path: :asc) }
  scope :with_repo, ->(repo_id) { where(repository_id: repo_id) }

  def absolute_path
    File.join(repository.root_path, path)
  end
end