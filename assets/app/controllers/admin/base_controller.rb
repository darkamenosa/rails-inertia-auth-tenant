# frozen_string_literal: true

module Admin
  class BaseController < InertiaController
    include Pagy::Method
    include BlockSearchEngineIndexing
    before_action :authenticate_identity!
    before_action :require_active_identity!
    before_action :require_staff!
    before_action :require_unscoped_access!

    private

      def require_staff!
        render_error_page(403, "Forbidden", "Staff access required.") unless Current.identity&.staff?
      end

      def require_unscoped_access!
        render_error_page(404, "Not Found", "Admin routes are not tenant-scoped.") if request.env["enlead.account_id"].present?
      end

      # Pagination helper - returns hash for Inertia props
      # Usage: pagination_props(pagy) => { page: 1, perPage: 25, total: 100, ... }
      def pagination_props(pagy)
        {
          page: pagy.page,
          per_page: pagy.limit,
          total: pagy.count,
          pages: pagy.last,
          from: pagy.from,
          to: pagy.to,
          has_previous: pagy.previous.present?,
          has_next: pagy.next.present?
        }
      end
  end
end
