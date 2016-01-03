require 'rounding'

class Membership < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :member
  belongs_to :basket
  belongs_to :distribution

  after_initialize :set_default_annual_halfday_works

  validates :member, presence: true
  validates :annual_halfday_works, presence: true
  validates :distribution, :basket, presence: true
  validates :started_on, :ended_on, presence: true
  validate :withing_basket_year
  validate :good_period_range
  validate :only_one_alongs_the_year
  validate :will_be_changed_at_good_date

  before_save :build_new_membership
  after_save :save_new_membership

  scope :started, -> { where('started_on < ?', Time.zone.now) }
  scope :past, -> { where('ended_on < ?', Time.zone.now) }
  scope :future, -> { where('started_on > ?', Time.zone.now) }
  scope :future_current_year, -> { future.during_year(Date.today.year) }
  scope :renew, -> { during_year(Time.zone.today.next_year.year) }
  scope :current, -> { including_date(Time.zone.today) }
  scope :current_year, -> { during_year(Date.today.year) }
  scope :including_date,
    ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :during_year, ->(year) {
    where(
      'started_on >= ? AND ended_on <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  attr_accessor :will_be_changed_at

  def will_be_changed_at=(date)
    if date.present?
      @will_be_changed_at = Date.parse(date)
    end
  end

  def self.billable
    during_year(Time.zone.today.year)
      .started
      .includes(
        :basket,
        :distribution,
        member: [:current_membership, :first_membership, :current_year_invoices]
      )
      .select(&:billable?)
  end

  def billable?
    price > 0 && !member.trial?
  end

  def current?
    started_on <= Time.zone.today && ended_on >= Time.zone.today
  end

  def can_destroy?
    deliveries_received_count == 0
  end

  def can_update?
    ended_on >= Time.zone.today
  end

  def halfday_works
    (deliveries_count / Delivery::PER_YEAR.to_f * annual_halfday_works).round
  end

  def halfday_works_basket_price
    halfday_works_annual_price.to_f / Delivery::PER_YEAR.to_f
  end

  def distribution_basket_price
    distribution.basket_price
  end

  def basket_total_price
    rounded_price(deliveries_count * basket.price)
  end

  def distribution_total_price
    rounded_price(deliveries_count * distribution_basket_price)
  end

  def halfday_works_total_price
    rounded_price(deliveries_count * halfday_works_basket_price)
  end

  def price
    basket_total_price + distribution_total_price + halfday_works_total_price
  end

  def description
    dates = [started_on, ended_on].map { |d| I18n.l(d, format: :number) }
    "Abonnement du #{dates.first} au #{dates.last} (#{deliveries_count} livraisons)"
  end

  def basket_description
    "Panier: #{basket.name} (#{deliveries_count} x #{cur(basket.price)})"
  end

  def distribution_description
    if distribution_basket_price > 0
      "Distribution: #{distribution.name} (#{deliveries_count} x #{cur(distribution.basket_price)})"
    else
      "Distribution: #{distribution.name} (gratuit)"
    end
  end

  def halfday_works_description
    diff = annual_halfday_works - HalfdayWork::MEMBER_PER_YEAR
    base =
      if diff > 0
        "Réduction pour #{diff} demi-journées de travail supplémentaires"
      elsif diff < 0
        "#{diff.abs} demi-journées de travail non effectuées"
      end
    "#{base} (#{deliveries_count} x #{cur(halfday_works_basket_price)})"
  end

  def deliveries_count
    Delivery.between(started_on..ended_on).count
  end

  def deliveries_received_count
    end_date = [ended_on, Time.zone.today].min
    Delivery.between(started_on..end_date).count
  end

  def date_range
    started_on..ended_on
  end

  def renew
    return if Membership.renew.exists?(member_id: member_id)
    renew_year = Time.zone.today.next_year
    Membership.create!(
      attributes.slice(*%i[
        halfday_works_annual_price
        annual_halfday_works
        note
      ]).merge(
        member: member,
        distribution: distribution,
        basket: Basket.find_by!(name: basket.name, year: renew_year.year),
        started_on: renew_year.beginning_of_year,
        ended_on: renew_year.end_of_year
      )
    )
  end

  private

  def set_default_annual_halfday_works
    self.annual_halfday_works ||= HalfdayWork::MEMBER_PER_YEAR
  end

  def build_new_membership
    if @will_be_changed_at
      attrs = attributes.except('id').merge('started_on' => @will_be_changed_at)
      @new_membership = Membership.new(attrs)
      reload
      self.ended_on = @will_be_changed_at - 1.day
    end
  end

  def save_new_membership
    @new_membership && @new_membership.save!
  end

  def only_one_alongs_the_year
    Membership.where(member: member).where.not(id: id).each do |membership|
      if membership.date_range.include?(started_on)
        errors.add(:started_on, 'déjà inclus dans un abonnement existant')
      end
      if membership.date_range.include?(ended_on)
        errors.add(:ended_on, 'déjà inclus dans un abonnement existant')
      end
      break
    end
  end

  def withing_basket_year
    if basket.year != started_on.year
      errors.add(:started_on, 'doit être durant la même année que le panier')
    end
    if basket.year != ended_on.year
      errors.add(:ended_on, 'doit être durant la même année que le panier')
    end
  end

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, 'doit être avant la fin')
      errors.add(:ended_on, 'doit être après le début')
    end
  end

  def will_be_changed_at_good_date
    if @will_be_changed_at && (
         @will_be_changed_at < Time.zone.today ||
         @will_be_changed_at <= started_on ||
         @will_be_changed_at >= ended_on
       )
      errors.add(:will_be_changed_at, :invalid)
    end
  end

  def rounded_price(price)
    return 0 if member.salary_basket?
    price.round_to_five_cents
  end

  def cur(number)
    precision = number.to_s.split('.').last.size > 2 ? 3 : 2
    ActiveSupport::NumberHelper
      .number_to_currency(number, unit: '', precision: precision).strip
  end
end
