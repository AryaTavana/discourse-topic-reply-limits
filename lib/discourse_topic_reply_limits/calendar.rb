# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module Calendar
    module_function

    def period_start(value = Time.zone.now)
      value.to_time.utc.to_date.beginning_of_month
    end

    def next_period(period_start)
      period_start.next_month.beginning_of_month
    end

    def period_time(period_start)
      Time.utc(period_start.year, period_start.month, 1)
    end

    def next_credit_at(period_start)
      period_time(next_period(period_start))
    end
  end
end
