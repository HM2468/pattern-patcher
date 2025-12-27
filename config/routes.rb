Rails.application.routes.draw do
  root "dashboard#index"

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  resources :lexical_patterns do
    member do
      get  :test
      post :run_test
      patch :toggle_enabled
    end
  end

  resources :repositories do
    member do
      get :import
    end
  end

  resources :repository_files, only: [] do
    collection do
      post :bulk_delete
    end
  end

  resources :occurrences, only: [:index, :show] do
    member do
      post :apply
      post :reject
      post :ignore
    end
  end

  resources :lexemes, only: [:index, :show] do
    collection do
      post :process_unprocessed
    end
  end

  resources :scan_runs, only: [:index, :create, :destroy] do
    member do
      get :sccanned_occurrences
      get :scanned_files
    end
  end

  resources :replacement_targets, only: [:index, :show, :edit, :update]
  resources :lexeme_processings, only: [:index, :show]
  resources :replacement_actions, only: [:index, :show]
  resources :settings, only: [:index, :edit, :update, :destroy]
end