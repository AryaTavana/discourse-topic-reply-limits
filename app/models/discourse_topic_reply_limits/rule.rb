# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class Rule < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_rules"

    MAX_REPLY_LIMIT = 1_000_000
    TRIAL_GROUP_NAMES = %w[trial forum trial].freeze

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
    validates :carryover_limit,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: MAX_REPLY_LIMIT
              },
              allow_nil: true

    def self.for_user_and_topic(user, topic_id)
      entitlement_group_id = Entitlement.find_by(user_id: user.id)&.group_id
      group_ids =
        GroupUser.where(user_id: user.id).pluck(:group_id) +
          [entitlement_group_id]
      rules =
        where(topic_id:, group_id: group_ids.compact.uniq)
          .includes(:group)
          .order(:group_id)
          .to_a

      trial_rule =
        rules.find do |rule|
          TRIAL_GROUP_NAMES.any? { |name| rule.group.name.casecmp?(name) }
        end
      trial_rule ? [trial_rule] : rules
    end
  end
end

# == Schema Information
#
# Table name: topic_reply_limit_rules
#
#  id                 :bigint           not null, primary key
#  carryover_limit    :integer
#  reply_limit        :integer          not null
#  warning_percentage :integer          default(80), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  group_id           :bigint           not null
#  topic_id           :bigint           not null
#
# Indexes
#
#  index_topic_reply_limit_rules_on_group_id               (group_id)
#  index_topic_reply_limit_rules_on_topic_id_and_group_id  (topic_id,group_id) UNIQUE
#
