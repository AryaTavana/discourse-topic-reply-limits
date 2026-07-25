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
      usages = CycleUsage.current_for_rules!(user:, topic:, rules:, at:)
      assignments =
        rules.map do |rule|
          usage = usages[rule.group_id]
          entitlement = Entitlement.current_for(user:, group: rule.group, at:)
          if usage && entitlement
            assignment_for(usage, entitlement)
          else
            unavailable_assignment(rule)
          end
        end
      next_credit_at =
        assignments.filter_map { |assignment| assignment[:next_credit_at] }.min
      refresh_at =
        assignments
          .flat_map do |assignment|
            [assignment[:next_credit_at], assignment[:subscription_ends_at]]
          end
          .compact
          .select { |timestamp| timestamp > at }
          .min

      {
        reached: assignments.any? { |assignment| assignment[:reached] },
        unavailable: assignments.any? { |assignment| assignment[:unavailable] },
        reply_count:
          assignments.map { |assignment| assignment[:reply_count] }.max,
        period_start:
          assignments
            .filter_map { |assignment| assignment[:cycle_started_at] }
            .min,
        next_credit_at:,
        refresh_at:,
        assignments:,
        warnings: assignments.select { |assignment| assignment[:warning] }
      }
    end

    def self.reached?(user:, topic:)
      self.for(user:, topic:)&.fetch(:reached, false) || false
    end

    def self.assignment_for(usage, entitlement)
      total_allowance = usage.total_allowance
      warning_at = (total_allowance * usage.warning_percentage + 99) / 100
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
        warning: !reached && usage.reply_count >= warning_at,
        unavailable: false,
        cycle_started_at: usage.cycle_started_at,
        cycle_ends_at: usage.cycle_ends_at,
        next_credit_at: usage.next_credit_at(entitlement),
        subscription_ends_at: entitlement.ends_at
      }
    end

    def self.unavailable_assignment(rule)
      {
        reply_limit: rule.reply_limit,
        monthly_reply_limit: rule.reply_limit,
        carried_in: 0,
        total_allowance: 0,
        warning_percentage: rule.warning_percentage,
        warning_at: 0,
        reply_count: 0,
        remaining: 0,
        reached: true,
        warning: false,
        unavailable: true,
        next_credit_at: nil
      }
    end

    private_class_method :assignment_for, :unavailable_assignment
  end
end
