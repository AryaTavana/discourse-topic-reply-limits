# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class RuleRevision < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_rule_revisions"

    validates :topic_id, :group_id, :effective_at, presence: true
    validates :reply_limit,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: Rule::MAX_REPLY_LIMIT
              },
              if: :active?
    validates :warning_percentage,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than: 100
              },
              if: :active?
    validates :carryover_limit,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: Rule::MAX_REPLY_LIMIT
              },
              allow_nil: true,
              if: :active?
    validates :reply_limit,
              :warning_percentage,
              :carryover_limit,
              absence: true,
              unless: :active?

    def self.record_active!(rule, at: Time.zone.now)
      latest =
        where(topic_id: rule.topic_id, group_id: rule.group_id).order(
          effective_at: :desc,
          id: :desc
        ).first
      if latest&.active? && latest.reply_limit == rule.reply_limit &&
           latest.warning_percentage == rule.warning_percentage &&
           latest.carryover_limit == rule.carryover_limit
        return latest
      end

      create!(
        topic_id: rule.topic_id,
        group_id: rule.group_id,
        effective_at: at,
        reply_limit: rule.reply_limit,
        warning_percentage: rule.warning_percentage,
        carryover_limit: rule.carryover_limit,
        active: true
      )
    end

    def self.record_inactive!(rule, at: Time.zone.now)
      ensure_for_rule!(rule)
      latest =
        where(topic_id: rule.topic_id, group_id: rule.group_id).order(
          effective_at: :desc,
          id: :desc
        ).first
      return latest unless latest&.active?

      create!(
        topic_id: rule.topic_id,
        group_id: rule.group_id,
        effective_at: at,
        active: false
      )
    end

    def self.ensure_for_rule!(rule)
      rule.with_lock do
        next if where(topic_id: rule.topic_id, group_id: rule.group_id).exists?

        create!(
          topic_id: rule.topic_id,
          group_id: rule.group_id,
          effective_at: rule.created_at,
          reply_limit: rule.reply_limit,
          warning_percentage: rule.warning_percentage,
          carryover_limit: rule.carryover_limit,
          active: true
        )
      end
    end

    def self.settings_for(
      topic_id:,
      group_id:,
      cycle_ends_at:,
      at: Time.zone.now
    )
      relation =
        where(topic_id:, group_id:).order(effective_at: :desc, id: :desc)

      if at >= cycle_ends_at
        relation.where("effective_at < ?", cycle_ends_at).first
      else
        relation.where("effective_at <= ?", at).first
      end
    end
  end
end

# == Schema Information
#
# Table name: topic_reply_limit_rule_revisions
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  carryover_limit    :integer
#  effective_at       :datetime         not null
#  reply_limit        :integer
#  warning_percentage :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  group_id           :bigint           not null
#  topic_id           :bigint           not null
#
# Indexes
#
#  idx_trll_rule_revisions_lookup  (topic_id,group_id,effective_at)
#
