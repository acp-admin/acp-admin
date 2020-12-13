require 'rails_helper'

describe RecurringBilling do
  before {
    travel_to(Date.new(Current.fy_year, 1, 15)) {
      create_deliveries(40)
    }
  }
  after { travel_back }

  def create_invoice(member)
    member.reload
    RecurringBilling.invoice(member)
  end

  it 'does not create an invoice for inactive member (non-support)' do
    member = create(:member, :inactive)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not create an invoice for member with future membership' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      Current.acp.update!(trial_basket_count: 0)
      member = create(:member)
      create(:membership, member: member, started_on: 1.day.from_now)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'creates an invoice for not already billed support member' do
    member = create(:member, :support_annual_fee)
    invoice = create_invoice(member)

    expect(invoice.object).to be_nil
    expect(invoice.object_type).to eq 'AnnualFee'
    expect(invoice.annual_fee).to be_present
    expect(invoice.memberships_amount).to be_nil
    expect(invoice.amount).to eq invoice.annual_fee
    expect(invoice.pdf_file).to be_attached
  end

  it 'does not create an invoice for already billed support member' do
    member = create(:member, :support_annual_fee)
    create(:invoice, :annual_fee, member: member)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not create an invoice for trial membership' do
    travel_to(Date.new(Current.fy_year, 1, 15)) do
      Current.acp.update!(trial_basket_count: 4)
      member = create(:member)

      membership = create(:membership, member: member,
        started_on: 1.week.ago)

      expect(membership.trial?).to eq true

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end

  it 'does not bill annual fee for canceled trial membership' do
    Current.acp.update!(
      billing_year_divisions: [12],
      trial_basket_count: 4)
    member = create(:member, :inactive, billing_year_division: 12)

    travel_to(Date.new(Current.fy_year, 8, 15))
    membership = create(:membership, member: member,
      started_on: 4.weeks.ago,
      ended_on: 1.day.ago)

    expect(membership.baskets_count).to eq 4

    invoice = create_invoice(member)

    expect(invoice.object).to eq membership
    expect(invoice.annual_fee).to be_nil
    expect(invoice.memberships_amount).to eq membership.price
    expect(invoice.pdf_file).to be_attached
  end

  it 'does not bill annual fee when member annual_fee is nil' do
    member = create(:member, :support_annual_fee)
    member.update_column(:annual_fee, nil)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'does not bill annual fee when member annual_fee is zero' do
    member = create(:member, :support_annual_fee)
    member.update_column(:annual_fee, 0)

    expect { create_invoice(member) }.not_to change(Invoice, :count)
  end

  it 'creates an invoice for already billed support member (last year)' do
    member = create(:member, :support_annual_fee)
    create(:invoice, :annual_fee, member: member, date: 1.year.ago)
    invoice = create_invoice(member)

    expect(invoice.object).to be_nil
    expect(invoice.annual_fee).to be_present
    expect(invoice.memberships_amount).to be_nil
    expect(invoice.amount).to eq invoice.annual_fee
    expect(invoice.pdf_file).to be_attached
  end

  context 'when billed yearly' do
    let(:member) { create(:member, :active, billing_year_division: 1) }
    let(:membership) { member.current_membership }

    specify 'when not already billed' do
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to eq 'Facturation annuelle'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'skip annual_fee when member one is set to 0' do
      member.update!(annual_fee: 0)

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
    end

    specify 'when not already billed with complements and many baskets' do
      create(:basket_complement, id: 1, price: 3.4, delivery_ids: Delivery.pluck(:id))
      create(:basket_complement, id: 2, price: 5.6, delivery_ids: Delivery.pluck(:id))

      travel_to(Current.fy_range.min) {
        membership.update!(
          basket_quantity: 2,
          basket_price: 32,
          depot_price: 3,
          memberships_basket_complements_attributes: {
            '0' => { basket_complement_id: 1, price: '', quantity: 1 },
            '1' => { basket_complement_id: 2, price: '', quantity: 2 }
          })
      }
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount)
        .to eq 40 * 2 * 32 + 40 * 2 * 3 + 40 * 3.4 + 40 * 2 * 5.6
      expect(invoice.memberships_amount_description).to eq 'Facturation annuelle'
      expect(invoice.memberships_amount).to eq membership.price
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when salary basket & support member' do
      member = create(:member, :support_annual_fee, salary_basket: true)
      invoice = create_invoice(member)

      expect(invoice.object).to be_nil
      expect(invoice.annual_fee).to be_present
      expect(invoice.memberships_amount).to be_nil
      expect(invoice.pdf_file).to be_attached
    end

    specify 'when already billed' do
      travel_to(Date.new(Current.fy_year, 1, 14)) { create_invoice(member) }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when membership did not started yet' do
      membership.update_column(:started_on, Date.tomorrow)

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when already billed, but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2, 15)) {
        membership.update!(depot_price: 2)
      }
      travel_to(Date.new(Current.fy_year, 1, 15))

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.object.baskets_count).to eq 40
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq 1200
      expect(invoice.memberships_amount_description).to be_present
      expect(invoice.memberships_amount).to eq 34 * 2
    end
  end

  context 'when billed quarterly' do
    let(:member) { create(:member, :active, billing_year_division: 4) }
    let(:membership) { member.current_membership }

    specify 'when quarter #1' do
      travel_to(Date.new(Current.fy_year, 1))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #1'
    end

    specify 'when quarter #1 (already billed)' do
      travel_to(Date.new(2019, 1, 14)) {
        create_invoice(member)
      }

      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #2' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #2'
    end

    specify 'when quarter #2 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 6)) {
        expect { create_invoice(member) }.not_to change(Invoice, :count)
      }
    end

    specify 'when quarter #2 (already billed but canceled)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5))
      create_invoice(member).cancel!
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #2'
    end

    specify 'when quarter #3' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #3'
    end

    specify 'when quarter #3 (with overpaid on previous invoices)' do
      @first_invoice = travel_to(Date.new(Current.fy_year, 1)) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 5)) {
        @second_invoice = create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))

      memberships_amount = membership.price / 4.0
      annual_fee = 30

      create(:payment, member: member, amount: memberships_amount + annual_fee + 15)
      create(:payment, member: member, amount: memberships_amount + 50)

      expect(@first_invoice.reload.overpaid).to be_zero
      expect(@second_invoice.reload.overpaid).to eq(65)
      invoice = create_invoice(member)

      expect(invoice.paid_memberships_amount).to eq membership.price / 2.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #3'

      invoice.reload
      expect(@first_invoice.reload.overpaid).to be_zero
      expect(@second_invoice.reload.overpaid).to be_zero
      expect(invoice.missing_amount).to eq(invoice.amount - 65)
    end

    specify 'when quarter #3 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 7).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))

      expect(RecurringBilling.new(member.reload)).not_to be_needed
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #3 (already billed), but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 7).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 8))
      membership.update!(depot_price: 2)

      expect(RecurringBilling.new(member.reload)).not_to be_needed
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end

    specify 'when quarter #4' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 11))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq membership.price * 3 / 4.0
      expect(invoice.remaining_memberships_amount).to eq membership.price - membership.price * 3 / 4.0
      expect(invoice.memberships_amount).to eq membership.price / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #4'
    end

    specify 'when quarter #4 (already billed)' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 10).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 11)) {
        expect(RecurringBilling.new(member.reload)).not_to be_needed
        expect { create_invoice(member) }.not_to change(Invoice, :count)
      }
    end

    specify 'when quarter #4 (already billed), but with a membership change' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 5)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 8)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 10).end_of_month) {
        create_invoice(member)
      }
      travel_to(Date.new(Current.fy_year, 11)) {
        membership.baskets.last.update!(depot_price: 2)
        invoice = create_invoice(member)

        expect(invoice.object).to eq membership
        expect(invoice.annual_fee).to be_nil
        expect(invoice.paid_memberships_amount).to eq 1200
        expect(invoice.remaining_memberships_amount).to eq 1 * 2
        expect(invoice.memberships_amount).to eq 1 * 2
        expect(invoice.memberships_amount_description).to eq 'Facturation trimestrielle #4'
      }
    end
  end

  context 'when billed mensualy' do
    before { Current.acp.update!(billing_year_divisions: [12]) }
    let(:member) { create(:member, :active, billing_year_division: 12) }
    let(:membership) { member.current_membership }

    specify 'when month #1' do
      travel_to(Date.new(Current.fy_year, 1))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_present
      expect(invoice.paid_memberships_amount).to be_zero
      expect(invoice.remaining_memberships_amount).to eq membership.price
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #1'
    end

    specify 'when month #3' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3))
      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq (membership.price / 12.0) * 2
      expect(invoice.remaining_memberships_amount).to eq membership.price - (membership.price / 12.0) * 2
      expect(invoice.memberships_amount).to eq membership.price / 12.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #3 but membership ends at the end the month' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      old_price = membership.price
      membership.update!(ended_on: Time.current.end_of_month)
      new_price = membership.price.to_f

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((old_price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #3 but membership ends in 3 months' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      old_price = membership.price
      membership.update!(ended_on: 3.months.from_now.end_of_month)
      new_price = membership.price.to_f

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((old_price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq new_price - (old_price / 12.0) * 2
      expect(invoice.memberships_amount).to eq (new_price - (old_price / 12.0) * 2.0) / 4.0
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #3'
    end

    specify 'when month #12' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 12, 15))

      invoice = create_invoice(member)

      expect(invoice.object).to eq membership
      expect(invoice.annual_fee).to be_nil
      expect(invoice.paid_memberships_amount).to eq((membership.price / 12.0) * 2)
      expect(invoice.remaining_memberships_amount).to eq membership.price - (membership.price / 12.0) * 2
      expect(invoice.memberships_amount).to eq invoice.remaining_memberships_amount
      expect(invoice.memberships_amount_description).to eq 'Facturation mensuelle #12'
    end

    specify 'when month #3 but membership ended last month' do
      travel_to(Date.new(Current.fy_year, 1)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 2)) { create_invoice(member) }
      travel_to(Date.new(Current.fy_year, 3, 15))

      membership.update!(ended_on: 1.month.ago)

      expect(RecurringBilling.new(member.reload)).not_to be_needed
      expect { create_invoice(member) }.not_to change(Invoice, :count)
    end
  end
end
