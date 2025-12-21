# app/jobs/repository_import_job.rb
require "digest"

class RepositoryImportJob < ApplicationJob
  queue_as :default

  # perform(repository_id)
  def perform(repository_id)
    repo = Repository.find_by(id: repository_id)
    return if repo.nil?

    root = repo.root_path.to_s
    return if root.blank?
    return unless Dir.exist?(root)

    exts = repo.permitted_extensions
    return if exts.empty?

    now = Time.current

    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |abs_path|
      next if File.directory?(abs_path)

      # ignore common noise
      next if abs_path.include?("/.git/") || abs_path.end_with?("/.git")

      ext = File.extname(abs_path).downcase
      next unless exts.include?(ext)

      rel = abs_path.sub(/\A#{Regexp.escape(root)}\/?/, "")
      size = File.size(abs_path)
      sha  = Digest::SHA256.file(abs_path).hexdigest

      rf = repo.repository_files.find_or_initialize_by(path: rel)
      rf.file_sha = sha
      rf.size_bytes = size
      rf.last_scanned_at = now
      rf.save!
    rescue => e
      Rails.logger.warn("[RepositoryImportJob] skip #{abs_path}: #{e.class}: #{e.message}")
      next
    end
  end
end