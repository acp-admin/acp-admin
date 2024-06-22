# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  include Templatable

  def activated_email
    member = params[:member]
    membership = member.current_or_future_membership
    basket = membership&.next_basket
    template_mail(member,
      tag: "member-activated",
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership),
      "basket" => Liquid::BasketDrop.new(basket))
  end

  def validated_email
    member = params[:member]
    template_mail(member,
      tag: "member-validated",
      "member" => Liquid::MemberDrop.new(member),
      "waiting_list_position" => Member.waiting.count + 1,
      "waiting_basket_size_id" => member.waiting_basket_size_id,
      "waiting_depot_id" => member.waiting_depot_id)
  end
end
