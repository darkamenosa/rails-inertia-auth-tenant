# frozen_string_literal: true

module App
  class MenusController < InertiaController
    include BlockSearchEngineIndexing
    before_action :authenticate_identity!
    before_action :require_active_identity!

    def show
      users = Current.identity.users.active.includes(:account)

      if users.one?
        redirect_to app_dashboard_path(account_id: users.first.account.id)
      else
        render_error_page(403, "Forbidden", "You don't have access to this account.")
      end
    end
  end
end
