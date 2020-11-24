class MemberMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def activated_email
    params.merge!(activated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :member_activated)
    MemberMailer.with(params).activated_email
  end

  def validated_email
    params.merge!(validated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :member_validated)
    MemberMailer.with(params).validated_email
  end

  private

  def activated_email_params
    {
      member: member,
      membership: membership
    }
  end

  def validated_email_params
    {
      member: member,
      waiting_list_position: Member.waiting.count + 1
    }
  end

  def membership
    basket_size = BasketSize.all.sample(random: random)
    OpenStruct.new(
      started_on: Date.today,
      ended_on: Current.fiscal_year.end_of_year,
      basket_size: basket_size,
      depot: Depot.visible.sample(random: random),
      remaning_trial_baskets_count: Current.acp.trial_basket_count,
      activity_participations_demanded: basket_size.activity_participations_demanded_annualy,
      basket_complements: BasketComplement.reorder(:id).sample(2, random: random))
  end
end

