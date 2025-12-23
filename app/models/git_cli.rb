# frozen_string_literal: true

class GitCli
  include ActiveModel::Model

  # include GitRepo::Command
  # include GitRepo::Checks
  # include GitRepo::Refs
  # include GitRepo::Tree
  # include GitRepo::Blobs
  # include GitRepo::Worktree
  # include GitRepo::Parsing
  # attr_reader :repository, :timeout_seconds, :logger
  validates :repository, presence: true

  def initialize(repository, timeout_seconds: 20, logger: nil)
    @timeout_seconds = timeout_seconds.to_i
    @logger = logger || (defined?(Rails) ? Rails.logger : nil)

    if repository.is_a?(Repository)
      @repository = repository
    else
      @repository = nil
      errors.add(:repository, "must be a Repository instance")
    end
  end

end