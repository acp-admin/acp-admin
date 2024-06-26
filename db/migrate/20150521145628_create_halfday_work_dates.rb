# frozen_string_literal: true

class CreateHalfdayWorkDates < ActiveRecord::Migration[4.2]
  def change
    create_table :halfday_work_dates do |t|
      t.date :date, null: false
      t.string :periods, array: true, null: false

      t.timestamps null: false
    end

    add_index :halfday_work_dates, :date
  end
end
