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
        end

        validates :topic_id, :assignments, presence: true
        validate :group_ids_are_unique

        def group_ids_are_unique
          ids = assignments.to_a.map(&:group_id)
          if ids.uniq.length != ids.length
            errors.add(:assignments, :duplicate_groups)
          end
        end
      end

      policy :can_manage_reply_limits
      model :topic
      model :groups

      transaction do
        step :replace_rules
        step :log_change
      end

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

      def replace_rules(topic:, params:)
        group_ids = params.assignments.map(&:group_id)
        Rule.where(topic_id: topic.id).where.not(group_id: group_ids).delete_all

        params.assignments.each do |assignment|
          rule =
            Rule.find_or_initialize_by(
              topic_id: topic.id,
              group_id: assignment.group_id
            )
          rule.update!(
            reply_limit: assignment.reply_limit,
            warning_percentage: assignment.warning_percentage
          )
        end
      end

      def log_change(topic:, params:, guardian:)
        StaffActionLogger.new(guardian.user).log_custom(
          "upsert_topic_reply_limits",
          topic_id: topic.id,
          subject: topic.title,
          group_limits:
            params
              .assignments
              .map do |assignment|
                "#{assignment.group_id}:#{assignment.reply_limit}@#{assignment.warning_percentage}%"
              end
              .join(",")
        )
      end
    end
  end
end
