ActiveAdmin.register Activity do
  menu parent: :activities_human_name, priority: 2
  actions :all, except: [:show]

  breadcrumb do
    links = [activities_human_name]
    unless params['action'] == 'index'
      links << link_to(Activity.model_name.human(count: 2), activities_path)
      if params['action'].in? %W[edit]
        links << activity.name
      end
    end
    links
  end

  scope :all
  scope :coming, default: true
  scope :past

  filter :place, as: :select, collection: -> { Activity.select(:places).distinct.map(&:place).compact.sort }
  filter :title, as: :select, collection: -> { Activity.select(:titles).distinct.map(&:title).compact.sort }
  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :participations
  index do
    column :date, ->(a) { l a.date, format: :medium }, sortable: :date
    column :period, ->(a) { a.period }
    column :place, ->(a) { display_place(a) }
    column :title, ->(a) { a.title }
    column :participants, ->(a) {
      text = [a.participations.sum(&:participants_count), a.participants_limit || '∞'].join(' / ')
      link_to text, activity_participations_path(q: { activity_id_eq: a.id }, scope: :all)
    }
    actions class: 'col-actions-2'
  end

  order_by(:date) do |order_clause|
    [order_clause.to_sql, "activities.start_time #{order_clause.order}"].join(', ')
  end

  csv do
    column(:date)
    column(:period)
    column(:place)
    column(:place_url)
    column(:title)
    column(:description)
    column(:participants) { |a| a.participations.sum(&:participants_count) }
    column(:participants_limit)
  end

  form do |f|
    render partial: 'bulk_dates', locals: { f: f, resource: resource }

    f.inputs t('formtastic.inputs.period') do
      f.input :start_time, as: :time_picker, input_html: {
        step: 900,
        value: resource&.start_time&.strftime('%H:%M')
      }
      f.input :end_time, as: :time_picker, input_html: {
        step: 900,
        value: resource&.end_time&.strftime('%H:%M')
      }
    end
    f.inputs t('formtastic.inputs.place_and_title') do
      if f.object.new_record? && ActivityPreset.any?
        f.input :preset_id,
          collection: ActivityPreset.all + [ActivityPreset.new(id: 0, place: ActivityPreset.human_attribute_name(:other))],
          include_blank: false
      end
      preset_present = f.object.preset.present?
      translated_input(f, :places, input_html: { disabled: preset_present, class: 'js-preset' })
      translated_input(f, :place_urls, input_html: { disabled: preset_present, class: 'js-preset' })
      translated_input(f, :titles, input_html: { disabled: preset_present, class: 'js-preset' })
    end
    f.inputs t('.details') do
      translated_input(f, :descriptions, as: :text, required: false, input_html: { rows: 4 })
      f.input :participants_limit, as: :number
    end
    f.actions
  end

  permit_params(
    :date, :start_time, :end_time,
    :preset_id, :participants_limit,
    :bulk_dates_starts_on, :bulk_dates_ends_on,
    :bulk_dates_weeks_frequency,
    bulk_dates_wdays: [],
    places: I18n.available_locales,
    place_urls: I18n.available_locales,
    titles: I18n.available_locales,
    descriptions: I18n.available_locales)

  before_build do |activity|
    activity.preset_id ||= ActivityPreset.first&.id
  end

  controller do
    include TranslatedCSVFilename
  end

  config.per_page = 25
  config.sort_order = 'date_asc'
end
