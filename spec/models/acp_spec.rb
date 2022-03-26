require 'rails_helper'

describe ACP do
  specify 'validates that activity_price cannot be 0' do
    acp = ACP.new(activity_price: nil)
    expect(acp).not_to have_valid(:activity_price)
  end

  specify 'validates activity_participations_demanded_logic liquid syntax' do
    acp = ACP.new(activity_participations_demanded_logic: <<~LIQUID)
      {% if member.salary_basket %}
    LIQUID

    expect(acp).not_to have_valid(:activity_participations_demanded_logic)
    expect(acp.errors[:activity_participations_demanded_logic])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  describe '#billing_year_divisions=' do
    it 'keeps only allowed divisions' do
      acp = ACP.new(billing_year_divisions: ['', '1', '6', '12'])
      expect(acp.billing_year_divisions).to eq [1, 12]
    end
  end

  describe 'url=' do
    it 'sets host at the same time' do
      acp = ACP.new(url: 'https://www.ragedevert.ch')
      expect(acp.host).to eq 'ragedevert'
    end
  end

  specify 'creates default deliveries cycle' do
    ACP.exit!
    create(:acp, tenant_name: 'test')
    ACP.enter!('test')

    expect(DeliveriesCycle.count).to eq 1
    expect(DeliveriesCycle.first).to have_attributes(
      names: {
        'de' => 'Alle',
        'fr' => 'Toutes',
        'it' => 'Tutte'
      })
  end
end
