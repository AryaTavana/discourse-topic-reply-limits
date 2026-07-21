# frozen_string_literal: true

require "digest"

module DiscourseTopicReplyLimits
  class Usage < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_period_usages"

    belongs_to :topic, -> { with_deleted }
    belongs_to :user
    belongs_to :group

    validates :period_start,
              uniqueness: {
                scope: %i[user_id topic_id group_id]
              }
    validates :monthly_allowance,
              numericality: {
                only_integer: true,
                greater_than: 0
              }
    validates :carried_in,
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
    validates :reply_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              }

    def total_allowance
      monthly_allowance + carried_in
    end

    def remaining
      [total_allowance - reply_count, 0].max
    end

    def self.current_for_rules!(user:, topic:, rules:, at: Time.zone.now)
      with_locked_current_for_rules!(user:, topic:, rules:, at:) { |rows| rows }
    end

    def self.with_locked_current_for_rules!(user:, topic:, rules:, at: Time.zone.now)
      transaction do
        acquire_transaction_lock(user_id: user.id, topic_id: topic.id)
        rows =
          rules.to_h do |rule|
            [rule.group_id, materialize_current!(user:, topic:, rule:, at:)]
          end
        block_given? ? yield(rows) : rows
      end
    end

    def self.materialize_current!(user:, topic:, rule:, at:)
      current_period = Calendar.period_start(at)
      MembershipPeriod.ensure_current!(user:, group: rule.group)
      RulePeriod.ensure_through!(rule:, through: current_period)

      previous =
        where(user_id: user.id, topic_id: topic.id, group_id: rule.group_id)
          .order(period_start: :desc)
          .first

      snapshots =
        RulePeriod
          .where(topic_id: topic.id, group_id: rule.group_id)
          .where("period_start <= ?", current_period)
          .order(:period_start)
      snapshots = snapshots.where("period_start > ?", previous.period_start) if previous
      snapshots = eligible_snapshots(user:, rule:, snapshots: snapshots.to_a)
      historical_stats =
        historical_reply_stats_by_period(
          user:,
          topic:,
          period_starts: snapshots.map(&:period_start)
        )

      snapshots.each do |snapshot|
        reply_count, last_reply_at =
          historical_stats.fetch(snapshot.period_start, [0, nil])
        previous =
          create!(
            user:,
            topic:,
            group: rule.group,
            period_start: snapshot.period_start,
            monthly_allowance: snapshot.reply_limit,
            warning_percentage: snapshot.warning_percentage,
            carried_in: previous&.remaining || 0,
            reply_count:,
            last_reply_at:
          )
      end

      return unless previous&.period_start == current_period

      historical_count, historical_last_reply_at =
        if snapshots.any? { |snapshot| snapshot.period_start == current_period }
          historical_stats.fetch(current_period, [0, nil])
        else
          historical_reply_stats_by_period(
            user:,
            topic:,
            period_starts: [current_period]
          ).fetch(current_period, [0, nil])
        end
      if historical_count > previous.reply_count
        previous.update!(
          reply_count: historical_count,
          last_reply_at: historical_last_reply_at
        )
      end
      previous
    end

    def self.eligible_snapshots(user:, rule:, snapshots:)
      intervals =
        MembershipPeriod.where(user_id: user.id, group_id: rule.group_id).to_a
      snapshots.select do |snapshot|
        period_start = Calendar.period_time(snapshot.period_start)
        period_end = Calendar.next_credit_at(snapshot.period_start)
        intervals.any? do |interval|
          interval.starts_at < period_end &&
            (
              interval.ends_at.nil? ||
                (
                  interval.ends_at > period_start &&
                    interval.ends_at > interval.starts_at
                )
            )
        end
      end
    end

    def self.historical_reply_stats_by_period(user:, topic:, period_starts:)
      return {} if period_starts.empty?

      period_sql =
        Arel.sql("DATE_TRUNC('month', posts.created_at)::date")
      rows =
        Post
        .with_deleted
        .where(
          user_id: user.id,
          topic_id: topic.id,
          post_type: Post.types[:regular]
        )
        .where.not(post_number: 1)
        .where(
          created_at:
            Calendar.period_time(period_starts.min)...Calendar.next_credit_at(
              period_starts.max
            )
        )
        .group(period_sql)
        .pluck(period_sql, Arel.sql("COUNT(*)"), Arel.sql("MAX(posts.created_at)"))

      rows.to_h do |period_start, count, last_reply_at|
        [period_start.to_date, [count, last_reply_at]]
      end
    end

    def self.acquire_transaction_lock(user_id:, topic_id:)
      key =
        Digest::SHA256.digest(
          "topic-reply-limits:#{topic_id}:#{user_id}"
        ).unpack1("q>")
      DB.exec("SELECT pg_advisory_xact_lock(?)", key)
    end

    private_class_method :materialize_current!,
                         :eligible_snapshots,
                         :historical_reply_stats_by_period,
                         :acquire_transaction_lock
  end
end
