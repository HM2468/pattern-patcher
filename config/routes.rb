Rails.application.routes.draw do
  # ------------------------------------------------------------
  # Health check endpoint
  #
  # GET /up
  # Returns 200 if the application boots successfully,
  # otherwise returns 500.
  #
  # Useful for load balancers and uptime monitoring.
  # ------------------------------------------------------------
  get "up" => "rails/health#show", as: :rails_health_check

  # ------------------------------------------------------------
  # Sidekiq Web UI
  #
  # Provides a web interface for monitoring background jobs.
  # NOTE: In production, this should be protected by
  # authentication / authorization middleware.
  # ------------------------------------------------------------
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # ------------------------------------------------------------
  # Application entry point
  # ------------------------------------------------------------
  root "dashboard#index"

  # ------------------------------------------------------------
  # Lexical patterns (regex rules)
  #
  # Manage scanning rules used to extract lexemes from source code.
  #
  # Includes an interactive regex testing tool for validating
  # matching behavior before running actual scans.
  # ------------------------------------------------------------
  resources :lexical_patterns do
    # Regex testing page:
    # GET  /lexical_patterns/:id/test
    # POST /lexical_patterns/:id/run_test
    member do
      get  :test
      post :run_test
    end
  end

  # ------------------------------------------------------------
  # Repositories and files
  #
  # A repository represents a local codebase root.
  # Repository files are individual files within the repository.
  #
  # NOTE:
  # The resource name "repositories" is intentionally left as-is
  # here, but in idiomatic Rails it should be "repositories".
  # ------------------------------------------------------------
  resources :repositories do
    # Nested routes for managing files within a repository
    resources :repository_files, only: [:index, :new, :create, :edit]
  end

  # File-level operations (show/edit/update/delete)
  resources :repository_files, only: [:show, :edit, :update, :destroy]

  # ------------------------------------------------------------
  # Scan runs
  #
  # Triggers a controlled scan of a single file using
  # a selected lexical pattern.
  #
  # Each scan run generates:
  # - One scan_run record
  # - Multiple lexeme records (deduplicated by fingerprint)
  # - Multiple occurrence records (per match)
  # ------------------------------------------------------------
  resources :scan_runs, only: [:index, :show, :create]

  # ------------------------------------------------------------
  # Occurrence review & replacement
  #
  # Occurrences represent the smallest reviewable unit:
  # a single matched lexeme at a specific location in a file.
  #
  # Human reviewers can:
  # - Apply the replacement
  # - Reject it with a reason
  # - Ignore it for future runs
  # ------------------------------------------------------------
  resources :occurrences, only: [:index, :show] do
    member do
      post :apply
      post :reject
      post :ignore
    end
  end

  # ------------------------------------------------------------
  # Lexeme processing
  #
  # Triggers background processing for unprocessed lexemes,
  # such as translation, normalization, or key generation.
  #
  # Typically backed by Sidekiq jobs calling LLM APIs.
  # ------------------------------------------------------------
  resources :lexemes, only: [:index, :show] do
    collection do
      post :process_unprocessed
    end
  end

  # ------------------------------------------------------------
  # Replacement targets
  #
  # Defines how a lexeme should be replaced in code,
  # e.g. I18n keys, constants, method calls, or comments.
  # ------------------------------------------------------------
  resources :replacement_targets, only: [:index, :show, :edit, :update]

  # ------------------------------------------------------------
  # Lexeme processing records
  #
  # Audit trail for all programmatic operations performed
  # on lexemes (translation, classification, key generation).
  # ------------------------------------------------------------
  resources :lexeme_processings, only: [:index, :show]

  # ------------------------------------------------------------
  # Replacement actions audit log
  #
  # Immutable history of all applied / skipped / rolled-back
  # code modifications, ensuring safety and traceability.
  # ------------------------------------------------------------
  resources :replacement_actions, only: [:index, :show]
end