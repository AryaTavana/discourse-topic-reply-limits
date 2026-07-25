# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module SubscriptionCycle
    module_function

    def at(anchor:, time: Time.zone.now)
      anchor = anchor.in_time_zone
      time = time.in_time_zone
      return if time < anchor

      index = ((time.year - anchor.year) * 12) + time.month - anchor.month
      index -= 1 if anchor.advance(months: index) > time
      started_at = anchor.advance(months: index)

      { index:, started_at:, ends_at: anchor.advance(months: index + 1) }
    end

    def intervals(anchor:, through:)
      current = at(anchor:, time: through)
      return [] unless current

      (0..current[:index]).map do |index|
        {
          index:,
          started_at: anchor.advance(months: index),
          ends_at: anchor.advance(months: index + 1)
        }
      end
    end
  end
end
