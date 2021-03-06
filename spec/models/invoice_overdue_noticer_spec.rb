require 'rails_helper'

describe InvoiceOverdueNoticer do
  before { MailTemplate.create! title: :invoice_overdue_notice }
  let(:invoice) { create(:invoice, :annual_fee, :open, sent_at: 40.days.ago) }

  def perform(invoice)
    InvoiceOverdueNoticer.perform(invoice)
  end

  it 'increments invoice overdue_notices_count' do
    expect { perform(invoice) }.to change(invoice, :overdue_notices_count).by(1)
  end

  it 'sets invoice overdue_notices_sent_at' do
    expect { perform(invoice) }
      .to change(invoice, :overdue_notice_sent_at).from(nil)
  end

  it 'sends invoice overdue_notice email' do
    expect { perform(invoice) }
      .to change { InvoiceMailer.deliveries.size }.by(1)
    mail = InvoiceMailer.deliveries.last
    expect(mail.subject).to eq "Rappel #1 de la facture ##{invoice.id} 😬"
  end

  specify 'only send overdue notice when invoice is open' do
    invoice = create(:invoice, :annual_fee, :open)
    create(:payment, invoice: invoice, amount: Current.acp.annual_fee)
    expect(invoice.reload.state).to eq 'closed'
    expect { perform(invoice) }
      .not_to change { InvoiceMailer.deliveries.size }
  end

  specify 'only send first overdue notice after 35 days' do
    invoice = create(:invoice, :annual_fee, sent_at: 10.days.ago)
    expect { perform(invoice) }
     .not_to change { InvoiceMailer.deliveries.size }
  end

  specify 'only send second overdue notice after 35 days first one' do
    invoice = create(:invoice, :annual_fee, :open,
      overdue_notices_count: 1,
      overdue_notice_sent_at: 10.days.ago
    )
    expect { perform(invoice) }
      .not_to change { InvoiceMailer.deliveries.size }
  end

  it 'sends second overdue notice after 35 days first one' do
    invoice = create(:invoice, :annual_fee, :open,
      overdue_notices_count: 1,
      overdue_notice_sent_at: 40.days.ago
    )
    expect { perform(invoice) }
      .to change { InvoiceMailer.deliveries.size }.by(1)

    mail = InvoiceMailer.deliveries.last
    expect(mail.subject).to eq "Rappel #2 de la facture ##{invoice.id} 😬"
    expect(invoice.overdue_notices_count).to eq 2
  end
end
