Rails.application.routes.draw do
  # Auth (Devise)
  devise_for :identities,
    path: "",
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      registration: "register",
      sign_up: ""
    },
    controllers: {
      sessions: "identities/sessions",
      registrations: "identities/registrations",
      passwords: "identities/passwords",
      omniauth_callbacks: "identities/omniauth_callbacks"
    }

  # App (authenticated identities with at least one active membership)
  authenticate :identity, ->(identity) { identity.active_for_authentication? && identity.users.active.exists? } do
    scope "app/:account_id", constraints: { account_id: /\d+/ } do
      namespace :app, path: "" do
        get "", to: "dashboards#show", as: :root
        resource :dashboard, only: :show
        resources :projects, only: [ :index ]
        resource :settings, only: [ :show, :update, :destroy ]
        resource :billing, only: :show
      end
    end
    get "app", to: "app/menus#show", as: :app
  end

  # Admin + system routes (staff identities only)
  authenticate :identity, ->(identity) { identity.active_for_authentication? && identity.staff? } do
    namespace :admin do
      resource :dashboard, only: :show
      resources :customers, only: [ :index, :show, :destroy ] do
        scope module: :customers do
          resource :suspension, only: [ :create, :destroy ]
          resource :staff_access, only: [ :create, :destroy ]
        end
      end
      namespace :customers do
        resource :bulk_suspension, only: [ :create, :destroy ]
        resource :bulk_deletion, only: :create
      end
      resources :webhooks, only: [ :index ]

      namespace :analytics do
        resource :live, only: :show
        resources :reports, only: [ :index ]
      end

      resource :settings, only: :show
      namespace :settings do
        resource :team, only: :show
        resource :billing, only: :show
      end
    end
    get "admin", to: redirect("/admin/dashboard")

    # System admin access — requires Identity.staff (not account role)
    mount MissionControl::Jobs::Engine, at: "/admin/jobs"
  end

  # Redirect to localhost from 127.0.0.1
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  # Public pages
  root "pages#home"
  get "about", to: "pages#about"
  get "pricing", to: "pages#pricing"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "contact", to: "pages#contact"

  # Error pages
  get "errors/:status", to: "errors#show", as: :error

  get "up" => "rails/health#show", as: :rails_health_check
end
