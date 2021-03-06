module ApplicationHelper
  def spaced(string, size: 3)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end

  def text_format(text)
    simple_format(text) if text.present?
  end

  def display_emails_with_link(arbre, emails)
    return unless emails.present?

    arbre.ul do
      Array(emails).map do |email|
        arbre.li do
          suppressions = EmailSuppression.outbound.where(email: email)
          if suppressions.any?
            arbre.s(email)
            suppressions.each do |suppression|
              arbre.status_tag suppression.reason.underscore
            end
            if suppressions.deletable.any?
              arbre.span do
                link_to(t('helpers.email_suppressions.destroy'), suppressions.first,
                  method: :delete,
                  class: 'button',
                  data: { confirm: t('helpers.email_suppressions.destroy_confirm') })
              end
            end
          else
            mail_to(email)
          end
        end
      end
    end
  end

  def display_phones_with_link(arbre, phones)
    return unless phones.present?

    arbre.ul do
      Array(phones).map do |phone|
        arbre.li do
          link_to(
            phone.phony_formatted,
            'tel:' + phone.phony_formatted(spaces: '', format: :international))
        end
      end
    end
  end

  def display_price_description(price, description)
    "#{cur(price)} #{"(#{description})" if price.positive?}"
  end

  def any_basket_complements?
    BasketComplement.any?
  end

  def seasons_collection
    ACP.seasons.map { |season| [I18n.t("season.#{season}"), season] }
  end

  def seasons_filter_collection
    filters = ACP.seasons + ACP.seasons.map { |s| s + '_only' }
    filters.map { |season| [I18n.t("season.#{season}"), season] }
  end

  def fiscal_years_collection
    min_year = Delivery.minimum(:date)&.year || Date.today.year
    max_year = Delivery.maximum(:date)&.year || Date.today.year
    (min_year..max_year).map { |year|
      fy = Current.acp.fiscal_year_for(year)
      [fy.to_s, fy.year]
    }.reverse
  end

  def renewal_states_collection
    %i[
      renewal_enabled
      renewal_opened
      renewal_canceled
      renewed
    ].map { |state|
      [I18n.t("active_admin.status_tag.#{state}").capitalize, state]
    }
  end

  def wdays_collection(novalue = nil)
    col = Array(0..6).rotate.map { |d| [I18n.t('date.day_names')[d].capitalize, d] }
    col = [[novalue, nil]] + col if novalue
    col
  end

  def referer_filter_member_id
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig('q', 'member_id_eq')
  end

  def postmark_url(path = 'streams')
    server_id = Current.acp.credentials(:postmark, :server_id)
    "https://account.postmarkapp.com/servers/#{server_id}/#{path}"
  end
end
