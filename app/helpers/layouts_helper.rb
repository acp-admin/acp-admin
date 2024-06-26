# frozen_string_literal: true

module LayoutsHelper
  def nav_class(controller)
    "active" if params[:controller].include? "members/#{controller}"
  end
end
