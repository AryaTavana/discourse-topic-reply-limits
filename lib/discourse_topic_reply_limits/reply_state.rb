# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class ReplyState
    def self.for(user:, topic:)
      return unless SiteSetting.topic_reply_limits_enabled
      if user.blank? || user.staff? || topic.blank? || topic.private_message?
        return
      end

      rules = Rule.for_user_and_topic(user, topic.id)
      return if rules.empty?

      at = Time.zone.now
      usages = Usage.current_for_rules!(user:, topic:, rules:, at:)
      assignments =
        rules.filter_map do |rule|
          usage = usages[rule.group_id]
          assignment_for(usage) if usage
        end
      return if assignments.empty?

      next_credit_at = Calendar.next_credit_at(Calendar.period_start(at))

      {
        reached: assignments.any? { |assignment| assignment[:reached] },
        reply_count: assignments.map { |assignment| assignment[:reply_count] }.max,
        period_start: Calendar.period_start(at),
        next_credit_at:,
        assignments:,
        warnings: assignments.select { |assignment| assignment[:warning] }
      }
    end

    def self.reached?(user:, topic:)
      self.for(user:, topic:)&.fetch(:reached, false) || false
    end

    def self.assignment_for(usage)
      total_allowance = usage.total_allowance
      warning_at =
        (total_allowance * usage.warning_percentage + 99) / 100
      remaining = usage.remaining
      reached = remaining.zero?

      {
        reply_limit: usage.monthly_allowance,
        monthly_reply_limit: usage.monthly_allowance,
        carried_in: usage.carried_in,
        total_allowance:,
        warning_percentage: usage.warning_percentage,
        warning_at:,
        reply_count: usage.reply_count,
        remaining:,
        reached:,
        warning: !reached && usage.reply_count >= warning_at
      }
    end

    private_class_method :assignment_for
  end
end
