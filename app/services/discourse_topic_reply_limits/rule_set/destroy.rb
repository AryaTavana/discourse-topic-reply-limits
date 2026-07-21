# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module RuleSet
    class Destroy
      include Service::Base

      params do
        attribute :topic_id, :integer
        validates :topic_id, presence: true
      end

      policy :can_manage_reply_limits
      model :topic
      model :rules

      transaction do
        step :log_change
        step :destroy_rules
      end

      private

      def can_manage_reply_limits(guardian:)
        guardian.is_admin?
      end

      def fetch_topic(params:)
        Topic.with_deleted.find_by(id: params.topic_id)
      end

      def fetch_rules(topic:)
        Rule.where(topic_id: topic.id)
      end

      def log_change(topic:, rules:, guardian:)
        StaffActionLogger.new(guardian.user).log_custom(
          "delete_topic_reply_limits",
          topic_id: topic.id,
          subject: topic.title,
          group_ids: rules.map(&:group_id).join(",")
        )
      end

      def destroy_rules(rules:)
        rules.destroy_all
      end
    end
  end
end
