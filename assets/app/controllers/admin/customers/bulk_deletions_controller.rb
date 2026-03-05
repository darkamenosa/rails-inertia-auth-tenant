# frozen_string_literal: true

module Admin
  module Customers
    class BulkDeletionsController < BaseController
      def create
        identities = Identity.where(id: safe_ids)
        count = identities.count
        identities.destroy_all

        redirect_to admin_customers_path, notice: "#{count} customer(s) deleted."
      end

      private

        def safe_ids
          params.expect(ids: []).map(&:to_i) - [ Current.identity.id ]
        end
    end
  end
end
