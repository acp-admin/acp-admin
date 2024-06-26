# frozen_string_literal: true

FactoryBot.define do
  factory :product, class: BasketContent::Product do
    name { Faker::Food.unique.vegetables }
  end
end
