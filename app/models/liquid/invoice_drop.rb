class Liquid::InvoiceDrop < Liquid::Drop
  include NumbersHelper

  private :currency_symbol, :cur
  private *ActiveSupport::NumberHelper.instance_methods

  def initialize(invoice)
    @invoice = invoice
  end

  def number
    @invoice.id
  end

  def date
    I18n.l(@invoice.date)
  end

  def state
    @invoice.state
  end

  def object_type
    @invoice.object_type
  end

  def amount
    cur(@invoice.amount)
  end

  def missing_amount
    cur(@invoice.missing_amount)
  end

  def overdue_notices_count
    @invoice.overdue_notices_count
  end
end
