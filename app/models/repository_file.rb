# app/models/repository_file.rb
class RepositoryFile < ApplicationRecord
  belongs_to :repository

  has_many :occurrences, dependent: :destroy
  has_many :replacement_targets, dependent: :destroy
  has_many :replacement_actions, dependent: :destroy

  validates :path, presence: true
  validates :path, uniqueness: { scope: :repository_id }
  validates :blob_sha, length: { is: 40 }, allow_nil: true

  scope :recently_scanned, -> { order(last_scanned_at: :desc) }
  scope :by_path, -> { order(path: :asc) }
  scope :with_repo, ->(repo_id) { where(repository_id: repo_id) }
  scope :path_starts_with, ->(prefix) {
    next all if prefix.blank?

    escape = "!"
    escaped = ActiveRecord::Base.sanitize_sql_like(prefix.to_s, escape)
    where("path LIKE ? ESCAPE '!'", "#{escaped}%")
  }

  def absolute_path
    File.join(repository.root_path, path)
  end
end