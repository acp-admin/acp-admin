class Ability
  include CanCan::Ability

  def initialize(admin)
    if admin.right? 'readonly'
      can :manage, Admin, id: admin.id
      can :read, available_models
      can :read, MailTemplate
      can :pdf, Invoice
    end
    if admin.right? 'standard'
      can :manage, [Activity, ActivityParticipation, Absence, Vegetable, BasketContent] & available_models
      can :create, ActiveAdmin::Comment
      can :update, [Basket, BasketComplement, Delivery]
    end
    if admin.right? 'admin'
      can :read, Admin
      can :manage, Delivery
      can :manage, ActivityPreset if Current.acp.feature?('activity')
      can :create, group_buying_models & available_models
      can :update, group_buying_models & available_models
      can :destroy, group_buying_models & available_models, can_destroy?: true
      can :cancel, [GroupBuying::Order] & available_models, can_cancel?: true
      can :create, [BasketComplement, Depot, Member, Membership, Payment, Invoice] & available_models
      can :update, [Depot, Member] & available_models
      can :destroy, ActiveAdmin::Comment
      can :destroy, [Member, Membership, Payment, Invoice], can_destroy?: true
      can :update, [Membership, Payment], can_update?: true
      can :force_recurring_billing, Member
      can :renew_all, Membership
      can :open_renewal_all, Membership
      can :open_renewal, Membership, can_send_email?: true
      can :enable_renewal, Membership
      can :renew, Membership
      can :cancel, Membership
      can :validate, Member, pending?: true
      can :deactivate, Member, can_deactivate?: true
      can :wait, Member, can_wait?: true
      can :send_email, Invoice, can_send_email?: true
      can :cancel, Invoice, can_cancel?: true
    end
    if admin.right? 'superadmin'
      can :manage, [Basket, BasketSize, BasketComplement,
                    Depot, Admin, ACP, Membership, Payment, MailTemplate]
      can :become, Member
    end
    cannot :destroy, [BasketSize, BasketComplement, Depot]
  end

  def available_models
    default = [
      Basket,
      BasketSize,
      BasketComplement,
      ActiveAdmin::Page,
      ActiveAdmin::Comment,
      Delivery,
      Depot,
      Invoice,
      Member,
      Membership,
      Payment
    ]
    if Current.acp.feature?('absence')
      default << Absence
    end
    if Current.acp.feature?('activity')
      default << Activity
      default << ActivityParticipation
    end
    if Current.acp.feature?('basket_content')
      default << BasketContent
      default << Vegetable
    end
    if Current.acp.feature?('group_buying')
      default += group_buying_models
    end
    default
  end

  def group_buying_models
    [
      GroupBuying::Delivery,
      GroupBuying::Producer,
      GroupBuying::Product,
      GroupBuying::Order
    ]
  end
end
