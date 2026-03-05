# frozen_string_literal: true

module App
  class BaseController < InertiaController
    include AccountScoped
  end
end
