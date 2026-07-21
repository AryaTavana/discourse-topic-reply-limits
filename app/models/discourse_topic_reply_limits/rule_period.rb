# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class RulePeriod < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_rule_periods"

    validates :topic_id, :group_id, :rule_id, :period_start, presence: true
    validates :period_start, uniqueness: { scope: %i[topic_id group_id] }
    validates :reply_limit,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: Rule::MAX_REPLY_LIMIT
              }
    validates :warning_percentage,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than: 100
              }

    def self.ensure_through!(rule:, through: Calendar.period_start)
      latest =
        where(topic_id: rule.topic_id, group_id: rule.group_id)
          .order(period_start: :desc)
          .first
      first_period = Calendar.period_start(rule.created_at)
      next_unrecorded =
        latest ? Calendar.next_period(latest.period_start) : first_period
      cursor = [first_period, next_unrecorded].max

      while cursor <= through
        create_or_find_by!(
          topic_id: rule.topic_id,
          group_id: rule.group_id,
          period_start: cursor
        ) do |snapshot|
          snapshot.rule_id = rule.id
          snapshot.reply_limit = rule.reply_limit
          snapshot.warning_percentage = rule.warning_percentage
        end
        cursor = Calendar.next_period(cursor)
      end
    end
  end
end
