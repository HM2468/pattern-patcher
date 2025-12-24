# app/jobs/repository_import_job.rb
class RepositoryImportJob < ApplicationJob
  queue_as :default

  # perform(repository_id)
  def perform(repository_id)
    repo = Repository.find_by(id: repository_id)
    return if repo.nil?

    root = repo.root_path.to_s
    return if root.blank?
    return unless Dir.exist?(root)

    now = Time.current
    git_cli = repo.git_cli
    # List all files in the repository
    file_paths = git_cli.list_blob_paths(exts: repo.permitted_extensions)

    file_paths.each do |blob_sha, path|
      rf = repo.repository_files.find_or_initialize_by(blob_sha: blob_sha, path: path)
      rf.last_scanned_at = now
      rf.save!
    rescue => e
      Rails.logger.warn("[RepositoryImportJob] skip #{path}: #{e.class}: #{e.message}")
      next
    end

  end
end