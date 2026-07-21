# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class Rule < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_rules"

    MAX_REPLY_LIMIT = 1_000_000

    belongs_to :topic, -> { with_deleted }
    belongs_to :group

    validates :topic_id, :group_id, presence: true
    validates :group_id, uniqueness: { scope: :topic_id }
    validates :reply_limit,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: MAX_REPLY_LIMIT
              }
    validates :warning_percentage,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than: 100
              }

    def self.for_user_and_topic(user, topic_id)
      where(topic_id:)
        .order(:group_id)
        .select { |rule| user.in_any_groups?([rule.group_id]) }
    end
  end
end
