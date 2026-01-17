Rails.application.routes.draw do
  root "dashboard#index"
  get "/wiki(/*path)", to: "dashboard#show", as: :wiki

  # Health check endpoint
  get "up" => "rails/health#show", :as => :rails_health_check

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

  resources :repository_files, only: [:index] do
    collection do
      post :bulk_delete
    end
  end

  resources :scan_runs, only: %i[index create destroy] do
    member do
      get :scanned_files
    end
  end

  resources :lexeme_processors do
    collection do
      get :guide
    end
    member do
      patch :toggle_enabled
    end
  end

  resources :lexemes do
    member do
      patch :toggle_ignore
    end
  end

  resources :occurrence_reviews do
    member do
      post :approve
      post :reject
    end
  end

  resources :occurrences, only: %i[index show]
  resources :process_runs, only: %i[index create destroy]
  resources :settings, only: %i[index edit update destroy]
end
