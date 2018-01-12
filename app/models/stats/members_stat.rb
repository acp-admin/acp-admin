class Stats::MembersStat < Stats::BaseStat
  def self.all
    [new(Date.current.year)]
  end

  def data
    stats.map { |key, value|
      [I18n.t("member.status.#{key}"), value]
    }.to_h
  end

  private

  def stats
    @stats ||= {
      waiting: (
        Member.pending.count +
        Member.waiting.count +
        Member.inactive.joins(:memberships).merge(Membership.future).count
      ),
      trial: Member.trial.count,
      active: Member.active.count,
      support: Member.support.count
    }.sort_by { |_k, v| -1 * v }.to_h
  end
end
