# frozen_string_literal: true

module AccountScoped
  extend ActiveSupport::Concern
  include BlockSearchEngineIndexing

  included do
    before_action :authenticate_identity!
    # Defined in ApplicationController, used here to centralize app-scope auth checks.
    before_action :require_active_identity!
    before_action :require_account!
  end

  private

    def require_account!
      unless Current.account && Current.user
        render_error_page(403, "Forbidden", "You don't have access to this account.")
      end
    end
end
