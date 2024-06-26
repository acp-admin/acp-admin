# frozen_string_literal: true

class Liquid::AdminMembershipDrop < Liquid::Drop
  def initialize(membership)
    @membership = membership
  end

  def id
    @membership.id
  end
end
