class FileScanService
  def initialize(repository:, scan_run:, repo_file:, pattern:)
    @repository = repository
    @scan_run = scan_run
    @repo_file = repo_file
    @pattern = pattern
  end

  def execute
    @git_cli = repository.git_cli
    @file_content = @git_cli.read_file(@repo_file.blob_sha)
    @regex = @pattern.compiled_regex
    ##
    # to-do
  end
end