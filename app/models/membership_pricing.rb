require 'rounding'

class MembershipPricing
  def initialize(params = {})
    @params = params
    @min = 0
    @max = 0
  end

  def prices
    @prices ||= begin
      add(baskets_prices)
      add(baskets_price_extras)
      add(depot_prices)
      complements_prices.each { |prices| add(prices) }

      [@min, @max].uniq
    end
  end

  def present?
    !simple_pricing? && prices.any?(&:positive?)
  end

  private

  def simple_pricing?
    Depot.visible.sum(:price).zero? &&
      BasketComplement.visible.sum(:price).zero? &&
      deliveries_counts.one? &&
      !Current.acp.feature?('basket_price_extra')
  end

  def basket_size
    @basket_size ||= BasketSize.find_by(id: @params[:waiting_basket_size_id])
  end

  def baskets_prices
    return [0, 0] unless basket_size

    [
      deliveries_counts.min * basket_size.price,
      deliveries_counts.max * basket_size.price
    ]
  end

  def baskets_price_extras
    extra = @params[:waiting_basket_price_extra].to_f
    return [0, 0] unless extra.positive?

    [
      deliveries_counts.min * calculate_price_extra(extra, basket_size, deliveries_counts.min),
      deliveries_counts.max * calculate_price_extra(extra, basket_size, deliveries_counts.max)
    ]
  end

  def calculate_price_extra(extra, basket_size, deliveries_count)
    return 0 unless Current.acp.feature?('basket_price_extra')
    return 0 unless basket_size

    Current.acp.calculate_basket_price_extra(
      extra,
      basket_size.price,
      basket_size.id,
      deliveries_count)
  end

  def complements_prices
    attrs = @params[:members_basket_complements_attributes].to_h
    return [[0, 0]] unless attrs.present?

    attrs.map { |_, attrs|
      complement_prices(attrs[:basket_complement_id], attrs[:quantity].to_i)
    }
  end

  def complement_prices(complement_id, quantity)
    complement = BasketComplement.find_by(id: complement_id)
    return [0, 0] unless complement
    return [0, 0] if quantity.zero?

    if complement.annual_price_type?
      [complement.price * quantity] * 2
    else
      deliveries_counts = deliveries_cycles.map { |dc|
        (complement.delivery_ids & dc.current_and_future_delivery_ids).size
      }.uniq
      [
        deliveries_counts.min * complement.price * quantity,
        deliveries_counts.max * complement.price * quantity
      ]
    end
  end

  def depot_prices
    return [0, 0] unless depot

    [
      deliveries_counts.min * depot.price,
      deliveries_counts.max * depot.price
    ]
  end

  def deliveries_counts
    return [0] unless deliveries_cycles.any?

    @deliveries_counts ||= deliveries_cycles.map(&:deliveries_count).flatten.uniq.sort
  end

  def deliveries_cycles
    return [deliveries_cycle] if deliveries_cycle

    @deliveries_cycles ||=
      DeliveriesCycle.find(depots.map(&:visible_deliveries_cycle_ids).flatten.uniq).to_a
  end

  def deliveries_cycle
    @deliveries_cycle ||=
      DeliveriesCycle.find_by(id: @params[:waiting_deliveries_cycle_id])
  end

  def depots
    return [depot] if depot

    @depots ||=
      Depot.visible.includes(:deliveries_cycles, :visibe_deliveries_cycles).to_a
  end

  def depot
    @depot ||= Depot.find_by(id: @params[:waiting_depot_id])
  end

  def add(prices)
    @min, @max =
      [@min, @max].zip(prices.map(&:round_to_five_cents)).map(&:sum)
  end
end