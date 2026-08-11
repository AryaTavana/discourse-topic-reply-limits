# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module RuleSet
    class Upsert
      include Service::Base

      params do
        attribute :topic_id, :integer
        attribute :assignments, :array do
          attribute :group_id, :integer
          attribute :reply_limit, :integer
          attribute :warning_percentage, :integer, default: 80
          attribute :carryover_limit, :integer

          validates :group_id, presence: true
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
          validates :carryover_limit,
                    numericality: {
                      only_integer: true,
                      greater_than_or_equal_to: 0,
                      less_than_or_equal_to: Rule::MAX_REPLY_LIMIT
                    },
                    allow_nil: true
        end

        validates :topic_id, :assignments, presence: true
        validate :group_ids_are_unique

        def group_ids_are_unique
          ids = assignments.to_a.map(&:group_id)
          if ids.uniq.length != ids.length
            errors.add(:assignments, :duplicate_groups)
          end
        end

        def group_limits_log
          assignments
            .map do |assignment|
              carryover = assignment.carryover_limit || "unlimited"
              "#{assignment.group_id}:#{assignment.reply_limit}@#{assignment.warning_percentage}%/carry:#{carryover}"
            end
            .join(",")
        end
      end

      policy :can_manage_reply_limits
      model :topic
      model :groups

      transaction { step :replace_rules }
      step :log_change

      private

      def can_manage_reply_limits(guardian:)
        guardian.is_admin?
      end

      def fetch_topic(params:)
        Topic.find_by(id: params.topic_id, archetype: Archetype.default)
      end

      def fetch_groups(params:)
        group_ids = params.assignments.map(&:group_id)
        groups = Group.where(id: group_ids).to_a
        groups if groups.length == group_ids.length
      end

      def replace_rules(topic:, groups:, params:)
        changed_at = Time.zone.now
        groups_by_id = groups.index_by(&:id)
        group_ids = params.assignments.map(&:group_id)
        removed_rules = Rule.where(topic:).where.not(group_id: group_ids)
        removed_rules.each do |rule|
          RulePeriod.ensure_through!(rule:)
          RuleRevision.record_inactive!(rule, at: changed_at)
        end
        removed_rules.delete_all

        params.assignments.each do |assignment|
          rule =
            Rule.find_or_initialize_by(
              topic:,
              group: groups_by_id.fetch(assignment.group_id)
            )
          RulePeriod.ensure_through!(rule:) if rule.persisted?
          RuleRevision.ensure_for_rule!(rule) if rule.persisted?
          rule.update!(
            reply_limit: assignment.reply_limit,
            warning_percentage: assignment.warning_percentage,
            carryover_limit: assignment.carryover_limit
          )
          RulePeriod.ensure_through!(rule:)
          RuleRevision.record_active!(rule, at: changed_at)
          MembershipPeriod.bootstrap_group!(rule.group_id)
        end
      end

      def log_change(topic:, params:, guardian:)
        StaffActionLogger.new(guardian.user).log_custom(
          "upsert_topic_reply_limits",
          topic_id: topic.id,
          subject: topic.title,
          group_limits: params.group_limits_log
        )
      end
    end
  end
end
