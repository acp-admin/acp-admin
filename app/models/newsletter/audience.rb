class Newsletter
  module Audience
    extend self
    CIPHER_KEY = 'aes-256-cbc'

    def encrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).encrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secrets.secret_key_base)
      s = cipher.update(email) + cipher.final
      s.unpack('H*')[0].downcase
    end

    def decrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).decrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secrets.secret_key_base)
      s = [email].pack("H*").unpack("C*").pack("c*")
      cipher.update(s) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      nil
    end

    class Segment < Struct.new(:key, :value, :name)
      def self.parse(audience)
        key, value = audience.split('::')
        Segment.new(key.to_sym, value)
      end

      def record
        Audience.record_for(key, value)
      end

      def name
        super || record&.name || I18n.t('newsletter.segment_unknown')
      end

      def id
        "#{key}::#{value}"
      end

      def members
        case key
        when :basket_size_id
          Member
            .joins(:current_membership)
            .where(memberships: { basket_size_id: value })
        when :basket_complement_id
          Member
            .joins(current_membership: :memberships_basket_complements)
            .where(memberships_basket_complements: { basket_complement_id: value })
        when :depot_id
          Member
            .joins(:current_membership)
            .where(memberships: { depot_id: value })
        when :member_state
          case value
          when 'all'; Member.not_pending
          when 'not_inactive'; Member.not_pending.not_inactive
          when 'waiting_active'; Member.where(state: %w[waiting active])
          else; Member.where(state: value)
          end
        when :activity_state
          case value
          when 'demanded'
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1..})
          when 'missing'
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1..})
              .where('activity_participations_demanded > activity_participations_accepted')
          end
        end
      end
    end

    def record_for(key, value)
      case key
      when :basket_size_id; BasketSize.find_by(id: value)
      when :basket_complement_id; BasketComplement.find_by(id: value)
      when :depot_id; Depot.find_by(id: value)
      when :member_state
        name =
          if Member::STATES.include?(value)
            I18n.t("states.member.#{value}").capitalize
          else
            I18n.t("newsletter.member_state.#{value}")
          end
        OpenStruct.new(id: value, name: name)
      when :activity_state
        OpenStruct.new(
          id: value,
          name: I18n.t("newsletter.activity_state.#{value}"))
      end
    end

    def segments
      base = {
        member_state: member_state_records,
        depot_id: Depot.used.reorder(:name),
        basket_size_id: BasketSize.all,
      }
      if BasketComplement.any?
        base[:basket_complement_id] = BasketComplement.all
      end
      if Current.acp.feature?('activity')
        base[:activity_state] = activity_state_records
      end
      base.map { |key, records|
        [key, records.map { |r| Segment.new(key, r.id, r.name) }.sort_by(&:name)]
      }.to_h
    end

    private

    def member_state_records
      states = Member::STATES - %w[pending]
      states += %w[all not_inactive waiting_active]
      states.map { |s| record_for(:member_state, s) }
    end

    def activity_state_records
      states = %w[demanded missing]
      states.map { |s| record_for(:activity_state, s) }
    end
  end
end