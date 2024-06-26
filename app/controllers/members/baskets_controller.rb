# frozen_string_literal: true

class Members::BasketsController < Members::BaseController
  before_action :load_basket
  before_action :ensure_member_can_update_basket!

  # GET /baskets/:id/edit
  def edit
  end

  # PATCH /baskets/:id
  def update
    @basket.member_update!(basket_params)
    redirect_to members_deliveries_path, notice: t("flash.actions.update.notice")
  end

  private

  def load_basket
    @basket = current_member.baskets.find(params[:id])
  end

  def ensure_member_can_update_basket!
    redirect_to members_deliveries_path unless @basket.can_member_update?
  end

  def basket_params
    permitted =
      params
        .require(:basket)
        .permit(
          :depot_id,
          baskets_basket_complements_attributes: [
            :id, :basket_complement_id, :quantity
          ])
    permitted[:baskets_basket_complements_attributes]&.each { |i, attrs|
      attrs["_destroy"] = true if attrs["quantity"].to_i.zero?
    }
    permitted
  end
end
