require 'rails_helper'

describe Ability do
  let(:ability) { Ability.new(admin) }

  context 'standard rights' do
    let(:admin) { create(:admin, rights: 'standard') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:read, Admin.new)).to be false }
    specify { expect(ability.can?(:read, MailTemplate)).to be true }
    specify { expect(ability.can?(:update, MailTemplate)).to be false }
    specify { expect(ability.can?(:manage, Member)).to be false }
    specify { expect(ability.can?(:create, Delivery)).to be false }
    specify { expect(ability.can?(:read, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be false }
    specify { expect(ability.can?(:validate, Member)).to be false }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be false }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be false }
    specify { expect(ability.can?(:destroy, ActiveAdmin::Comment)).to be false }
    specify { expect(ability.can?(:create, ActiveAdmin::Comment)).to be true }
    specify { expect(ability.can?(:destroy, Invoice)).to be false }
  end

  context 'admin rights' do
    let(:admin) { create(:admin, rights: 'admin') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:read, Admin.new)).to be true }
    specify { expect(ability.can?(:read, MailTemplate)).to be true }
    specify { expect(ability.can?(:update, MailTemplate)).to be false }
    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:manage, Delivery)).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'support'))).to be true }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be true }
    specify { expect(ability.can?(:destroy, ActiveAdmin::Comment)).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new)).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(sent_at: Time.current))).to be false }

    context 'share price' do
      before { Current.acp.update!(share_price: 420) }

      specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
      specify { expect(ability.can?(:deactivate, Member.new(state: 'support'))).to be false }
    end
  end

  context 'superadmin rights' do
    let(:admin) { create(:admin, rights: 'superadmin') }

    specify { expect(ability.can?(:manage, admin)).to be true }
    specify { expect(ability.can?(:manage, Admin.new)).to be true }
    specify { expect(ability.can?(:create, MailTemplate)).to be true }
    specify { expect(ability.can?(:create, Member)).to be true }
    specify { expect(ability.can?(:update, Member)).to be true }
    specify { expect(ability.can?(:destroy, Member)).to be true }
    specify { expect(ability.can?(:validate, Member)).to be true }
    specify { expect(ability.can?(:deactivate, Member.new(state: 'waiting'))).to be true }
    specify { expect(ability.can?(:wait, Member.new(state: 'inactive'))).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new)).to be true }
    specify { expect(ability.can?(:destroy, Invoice.new(sent_at: Time.current))).to be false }
    specify { expect(ability.can?(:destroy, BasketSize)).to be false }
    specify { expect(ability.can?(:destroy, BasketComplement)).to be false }
  end
end
