# frozen_string_literal: true

require "rounding"

class InvoiceItem < ApplicationRecord
  belongs_to :invoice

  validates :description, presence: true
  validates :amount, presence: true, numericality: true
end
