# app/models/repository_file.rb
class RepositoryFile < ApplicationRecord
  belongs_to :repository

  has_many :occurrences, dependent: :delete_all
  has_many :scan_run_files, dependent: :delete_all

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

  def raw_content
    abs = absolute_path.to_s
    return "" if abs.blank?

    File.read(abs)
  rescue Errno::ENOENT, Errno::ENOTDIR => e
    Rails.logger.warn(
      "[RepositoryFile#raw_content] file not found",
      repository_id: repository_id,
      path: path,
      absolute_path: abs,
      error: e.class.name,
      message: e.message
    )
    ""
  rescue Errno::EACCES => e
    Rails.logger.error(
      "[RepositoryFile#raw_content] permission denied",
      repository_id: repository_id,
      path: path,
      absolute_path: abs,
      error: e.class.name,
      message: e.message
    )
    ""
  rescue Encoding::InvalidByteSequenceError,
        Encoding::UndefinedConversionError,
        ArgumentError => e
    Rails.logger.warn(
      "[RepositoryFile#raw_content] encoding issue, fallback to binary read",
      repository_id: repository_id,
      path: path,
      absolute_path: abs,
      error: e.class.name,
      message: e.message
    )

    begin
      File.binread(abs).force_encoding("UTF-8").scrub
    rescue StandardError => e2
      Rails.logger.error(
        "[RepositoryFile#raw_content] binary read failed",
        repository_id: repository_id,
        path: path,
        absolute_path: abs,
        error: e2.class.name,
        message: e2.message
      )
      ""
    end
  rescue StandardError => e
    Rails.logger.error(
      "[RepositoryFile#raw_content] unexpected error",
      repository_id: repository_id,
      path: path,
      absolute_path: abs,
      error: e.class.name,
      message: e.message,
      backtrace: e.backtrace&.first(10)
    )
    ""
  end
end