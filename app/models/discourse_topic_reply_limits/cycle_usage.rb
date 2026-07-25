# frozen_string_literal: true

require "digest"

module DiscourseTopicReplyLimits
  class CycleUsage < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_cycle_usages"

    belongs_to :topic, -> { with_deleted }
    belongs_to :user
    belongs_to :group

    validates :cycle_started_at,
              uniqueness: {
                scope: %i[user_id topic_id group_id entitlement_external_id]
              }
    validates :monthly_allowance,
              numericality: {
                only_integer: true,
                greater_than: 0
              }
    validates :carried_in,
              :reply_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              }
    validates :warning_percentage,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than: 100
              }

    def total_allowance
      monthly_allowance + carried_in
    end

    def remaining
      [total_allowance - reply_count, 0].max
    end

    def next_credit_at(entitlement)
      return unless entitlement
      return cycle_ends_at if entitlement.ends_at.nil?
      cycle_ends_at if cycle_ends_at < entitlement.ends_at
    end

    def self.current_for_rules!(user:, topic:, rules:, at: Time.zone.now)
      with_locked_current_for_rules!(user:, topic:, rules:, at:) { |rows| rows }
    end

    def self.with_locked_current_for_rules!(
      user:,
      topic:,
      rules:,
      at: Time.zone.now
    )
      transaction do
        acquire_user_topic_lock!(user_id: user.id, topic_id: topic.id)
        rows =
          rules.to_h do |rule|
            entitlement = Entitlement.current_for(user:, group: rule.group, at:)
            [
              rule.group_id,
              entitlement &&
                materialize_current!(user:, topic:, rule:, entitlement:, at:)
            ]
          end
        block_given? ? yield(rows) : rows
      end
    end

    def self.materialize_current!(user:, topic:, rule:, entitlement:, at:)
      cycle = SubscriptionCycle.at(anchor: entitlement.starts_at, time: at)
      return unless cycle
      return if entitlement.ends_at.present? && entitlement.ends_at <= at

      RuleRevision.ensure_for_rule!(rule)
      previous = nil
      intervals =
        SubscriptionCycle.intervals(anchor: entitlement.starts_at, through: at)
      reply_stats =
        historical_reply_stats_by_cycle(user:, topic:, entitlement:, intervals:)

      intervals.each do |interval|
        if entitlement.ends_at.present? &&
             interval[:started_at] >= entitlement.ends_at
          break
        end

        settings =
          RuleRevision.settings_for(
            topic_id: topic.id,
            group_id: rule.group_id,
            cycle_started_at: interval[:started_at],
            cycle_ends_at: interval[:ends_at]
          )
        unless settings&.active?
          previous = nil
          next
        end

        count, last_reply_at = reply_stats.fetch(interval[:index], [0, nil])
        row =
          find_or_create_by!(
            user:,
            topic:,
            group: rule.group,
            entitlement_external_id: entitlement.external_id,
            cycle_started_at: interval[:started_at]
          ) do |usage|
            usage.cycle_ends_at = interval[:ends_at]
            usage.monthly_allowance = settings.reply_limit
            usage.warning_percentage = settings.warning_percentage
            usage.carried_in = previous&.remaining || 0
            usage.reply_count = count
            usage.last_reply_at = last_reply_at
          end
        if count > row.reply_count
          row.update!(reply_count: count, last_reply_at:)
        end
        previous = row
      end

      return unless previous&.cycle_started_at == cycle[:started_at]

      previous
    end

    def self.historical_reply_stats_by_cycle(
      user:,
      topic:,
      entitlement:,
      intervals:
    )
      return {} if intervals.empty?

      range_end = [
        intervals.last[:ends_at],
        entitlement.ends_at || intervals.last[:ends_at]
      ].min
      posts =
        Post
          .with_deleted
          .where(
            user_id: user.id,
            topic_id: topic.id,
            post_type: Post.types[:regular],
            created_at: entitlement.starts_at...range_end
          )
          .where.not(post_number: 1)
          .pluck(:created_at)

      posts
        .group_by do |created_at|
          SubscriptionCycle.at(anchor: entitlement.starts_at, time: created_at)[
            :index
          ]
        end
        .to_h do |index, timestamps|
          [index, [timestamps.length, timestamps.max]]
        end
    end

    def self.acquire_user_topic_lock!(user_id:, topic_id:)
      acquire_user_topic_locks!([[user_id, topic_id]])
    end

    def self.acquire_user_topic_locks!(pairs)
      keys =
        pairs.uniq.map do |user_id, topic_id|
          Digest::SHA256.digest(
            "topic-reply-limits:#{topic_id}:#{user_id}"
          ).unpack1("q>")
        end
      keys.uniq.sort.each do |key|
        DB.exec("SELECT pg_advisory_xact_lock(?)", key)
      end
    end

    private_class_method :materialize_current!, :historical_reply_stats_by_cycle
  end
end

# == Schema Information
#
# Table name: topic_reply_limit_cycle_usages
#
#  id                      :bigint           not null, primary key
#  carried_in              :bigint           default(0), not null
#  cycle_ends_at           :datetime         not null
#  cycle_started_at        :datetime         not null
#  last_reply_at           :datetime
#  monthly_allowance       :integer          not null
#  reply_count             :bigint           default(0), not null
#  warning_percentage      :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  entitlement_external_id :string           not null
#  group_id                :bigint           not null
#  topic_id                :bigint           not null
#  user_id                 :bigint           not null
#
# Indexes
#
#  idx_trll_cycle_usages_identity          (user_id,topic_id,group_id,entitlement_external_id,cycle_started_at) UNIQUE
#  idx_trll_cycle_usages_topic_cycle       (topic_id,cycle_started_at)
#  idx_trll_cycle_usages_user_group_cycle  (user_id,group_id,cycle_started_at)
#
