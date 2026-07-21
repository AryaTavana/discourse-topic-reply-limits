# frozen_string_literal: true

require "digest"

module DiscourseTopicReplyLimits
  class MembershipPeriod < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_membership_periods"

    validates :user_id, :group_id, :starts_at, presence: true
    validate :ends_after_start

    def self.activate!(user_id:, group_id:, at: Time.zone.now)
      transaction do
        acquire_lock(user_id:, group_id:)
        current = find_by(user_id:, group_id:, ends_at: nil)
        if current
          current
        else
          # A closed interval proves this is a later subscription. Clear any
          # stale ledger left by an older plugin version before starting fresh.
          if where(user_id:, group_id:).where.not(ends_at: nil).exists?
            Usage.where(user_id:, group_id:).delete_all
          end
          create_or_find_by!(user_id:, group_id:, ends_at: nil) do |period|
            period.starts_at = at
          end
        end
      end
    end

    def self.deactivate!(user_id:, group_id:, at: Time.zone.now, starts_at: nil)
      transaction do
        acquire_usage_locks(user_id:, group_id:)
        acquire_lock(user_id:, group_id:)
        current = find_by(user_id:, group_id:, ends_at: nil)
        period =
          if current
            current.update!(ends_at: [at, current.starts_at].max)
            current
          elsif starts_at.present? && starts_at <= at
            find_or_create_by!(user_id:, group_id:, starts_at:) do |row|
              row.ends_at = at
            end
          end

        # Expiration removes both the current allowance and all carryover for
        # this subscription group. Post history remains authoritative audit
        # data, but a later membership starts a fresh allowance ledger.
        Usage.where(user_id:, group_id:).delete_all
        period
      end
    end

    def self.ensure_current!(user:, group:)
      # Multiple replies may share this lightweight row lock, while a group
      # removal must wait. This makes the membership decision atomic with the
      # surrounding reply transaction without serializing ordinary replies.
      membership =
        GroupUser
          .lock("FOR KEY SHARE")
          .find_by(user_id: user.id, group_id: group.id)
      return unless membership

      activate!(
        user_id: user.id,
        group_id: group.id,
        at: membership.created_at
      )
    end

    def self.bootstrap_group!(group_id)
      DB.exec(
        <<~SQL,
          INSERT INTO topic_reply_limit_membership_periods
            (user_id, group_id, starts_at, created_at, updated_at)
          SELECT
            gu.user_id, gu.group_id, gu.created_at, CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          FROM group_users gu
          WHERE gu.group_id = :group_id
          ON CONFLICT (user_id, group_id) WHERE ends_at IS NULL DO NOTHING
        SQL
        group_id:
      )
    end

    def self.tracked?(user_id:, group_id:)
      Rule.where(group_id:).exists? || where(user_id:, group_id:).exists?
    end

    def self.acquire_lock(user_id:, group_id:)
      key =
        Digest::SHA256.digest(
          "topic-reply-limits-membership:#{group_id}:#{user_id}"
        ).unpack1("q>")
      DB.exec("SELECT pg_advisory_xact_lock(?)", key)
    end

    def self.acquire_usage_locks(user_id:, group_id:)
      topic_ids =
        Rule.where(group_id:).pluck(:topic_id) +
          Usage.where(user_id:, group_id:).distinct.pluck(:topic_id)
      topic_ids.uniq.sort.each do |topic_id|
        Usage.acquire_user_topic_lock!(user_id:, topic_id:)
      end
    end

    def ends_after_start
      if ends_at.present? && starts_at.present? && ends_at < starts_at
        errors.add(:ends_at, "must be on or after the membership start")
      end
    end

    private_class_method :acquire_lock, :acquire_usage_locks
  end
end
