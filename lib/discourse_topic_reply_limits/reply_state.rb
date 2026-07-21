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

      reply_count = Usage.count_for(user:, topic:)
      assignments = rules.map { |rule| assignment_for(rule, reply_count) }

      {
        reached: assignments.any? { |assignment| assignment[:reached] },
        reply_count:,
        assignments:,
        warnings: assignments.select { |assignment| assignment[:warning] }
      }
    end

    def self.reached?(user:, topic:)
      self.for(user:, topic:)&.fetch(:reached, false) || false
    end

    def self.assignment_for(rule, reply_count)
      warning_at = (rule.reply_limit * rule.warning_percentage + 99) / 100
      remaining = [rule.reply_limit - reply_count, 0].max
      reached = reply_count >= rule.reply_limit

      {
        reply_limit: rule.reply_limit,
        warning_percentage: rule.warning_percentage,
        warning_at:,
        reply_count:,
        remaining:,
        reached:,
        warning: !reached && reply_count >= warning_at
      }
    end

    private_class_method :assignment_for
  end
end
