namespace :activity_participations do
  desc 'Send activity participations reminder emails'
  task send_reminder_emails: :environment do
    ACP.enter_each! do
      participations =
        ActivityParticipation
          .coming
          .includes(:activity, :member)
          .select(&:reminderable?)
          .select(&:notificable?)
      grouped_participations = ActivityParticipationGroup.group(participations)

      grouped_participations.each do |participation|
        Email.deliver_now(:member_activity_reminder, participation)
        participation.touch(:latest_reminder_sent_at)
      end

      puts "#{Current.acp.name}: activity participations reminder emails sent."
    end
  end

  desc 'Send activity participations review emails'
  task send_review_emails: :environment do
    ACP.enter_each! do
      validated_participations =
        ActivityParticipation
          .validated
          .review_not_sent
          .includes(:activity, :member)
          .select(&:notificable?)
      ActivityParticipationGroup
        .group(validated_participations)
        .each { |participation|
          Email.deliver_now(:member_activity_validated, participation)
          participation.touch(:review_sent_at)
        }

      rejected_participations =
        ActivityParticipation
          .rejected
          .review_not_sent
          .includes(:activity, :member)
          .select(&:notificable?)
      ActivityParticipationGroup
        .group(rejected_participations)
        .each { |participation|
          Email.deliver_now(:member_activity_rejected, participation)
          participation.touch(:review_sent_at)
        }

      puts "#{Current.acp.name}: activity participations review emails sent."
    end
  end
end
