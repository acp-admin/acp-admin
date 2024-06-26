# frozen_string_literal: true

class AddNewFormPriorityAndPublicNamesColumnsToBasketComplements < ActiveRecord::Migration[6.1]
  def change
    add_column :basket_complements, :public_names, :jsonb, default: {}, null: false
    add_column :basket_complements, :form_priority, :integer, default: 0, null: false
  end
end
