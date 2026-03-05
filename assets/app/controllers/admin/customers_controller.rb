# frozen_string_literal: true

module Admin
  class CustomersController < BaseController
    def index
      base = params[:query].present? ? Identity.search(params[:query]) : Identity.all
      scope = apply_status_filter(base)

      pagy, identities = pagy(scope.includes(:users).order(sort_column => sort_direction), limit: 25)

      render inertia: "admin/customers/index", props: {
        customers: identities.map { |i| customer_props(i) },
        pagination: pagination_props(pagy),
        counts: {
          all: base.count,
          active: base.active.count,
          suspended: base.suspended.count
        },
        filters: {
          status: params[:status] || "all",
          query: params[:query] || "",
          sort: params[:sort] || "created_at",
          direction: params[:direction] || "desc"
        }
      }
    end

    def show
      identity = Identity.includes(users: :account).find(params[:id])

      render inertia: "admin/customers/show", props: {
        customer: customer_detail_props(identity),
        is_self: identity == Current.identity
      }
    end

    def destroy
      identity = Identity.find(params[:id])

      if identity == Current.identity
        redirect_to admin_customers_path, alert: "You cannot delete your own account."
        return
      end

      identity.destroy
      redirect_to admin_customers_path, notice: "Customer deleted successfully."
    end

    private

      def apply_status_filter(scope)
        case params[:status]
        when "active" then scope.active
        when "suspended" then scope.suspended
        else scope
        end
      end

      def sort_column
        %w[email created_at].include?(params[:sort]) ? params[:sort] : "created_at"
      end

      def sort_direction
        %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
      end

      def customer_props(identity)
        {
          id: identity.id,
          email: identity.email,
          name: identity.display_name,
          auth_method: identity.auth_method,
          staff: identity.staff?,
          status: identity.status,
          accounts_count: identity.users.size,
          created_at: identity.created_at.iso8601
        }
      end

      def customer_detail_props(identity)
        {
          id: identity.id,
          email: identity.email,
          name: identity.display_name,
          auth_method: identity.auth_method,
          staff: identity.staff?,
          status: identity.status,
          suspended_at: identity.suspended_at&.iso8601,
          created_at: identity.created_at.iso8601,
          memberships: identity.users.map { |user|
            {
              id: user.id,
              account_id: user.account_id,
              account_name: user.account.name,
              role: user.role,
              name: user.name,
              active: user.active?,
              created_at: user.created_at.iso8601
            }
          }
        }
      end
  end
end
