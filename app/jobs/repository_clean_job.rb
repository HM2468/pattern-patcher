# app/jobs/repository_clean_job.rb
class RepositoryCleanJob < ApplicationJob
  queue_as :default

  def perform(repo_id)
    file_ids = RepositoryFile.where(repository_id: repo_id).pluck(:id)
    RepositoryFile.where(repository_id: repo_id).delete_all
    Occurrence.where(repository_file_id: file_ids).delete_all
    ReplacementTarget.where(repository_file_id: file_ids).delete_all
    ReplacementAction.where(repository_file_id: file_ids).delete_all
  end
end