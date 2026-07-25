# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class Entitlement < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_entitlements"

    belongs_to :user
    belongs_to :group, optional: true

    validates :user_id, :external_id, :starts_at, presence: true
    validates :group_id, presence: true, unless: :revoked?
    validates :user_id, :external_id, uniqueness: true
    validate :ends_after_start

    def active_at?(at)
      !revoked? && starts_at <= at && (ends_at.nil? || ends_at > at)
    end

    def revoked?
      revoked_at.present?
    end

    def self.current_for(user:, group:, at: Time.zone.now)
      external = find_by(user_id: user.id)
      if external&.group_id == group.id && external.active_at?(at)
        return external
      end
      return if external

      membership = MembershipPeriod.ensure_current!(user:, group:)
      return unless membership

      new(
        user:,
        group:,
        external_id: "membership-period:#{membership.id}",
        starts_at: membership.starts_at
      )
    end

    def self.usage_lock_pairs(user_id:, group_ids:)
      topic_ids =
        Rule.where(group_id: group_ids).distinct.pluck(:topic_id) +
          CycleUsage.where(user_id:).distinct.pluck(:topic_id)
      topic_ids.uniq.map { |topic_id| [user_id, topic_id] }
    end

    private

    def ends_after_start
      return if ends_at.blank? || starts_at.blank? || ends_at > starts_at

      errors.add(:ends_at, "must be after the entitlement start")
    end
  end
end

# == Schema Information
#
# Table name: topic_reply_limit_entitlements
#
#  id          :bigint           not null, primary key
#  ends_at     :datetime
#  revoked_at  :datetime
#  starts_at   :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string           not null
#  group_id    :bigint
#  user_id     :bigint           not null
#
# Indexes
#
#  index_topic_reply_limit_entitlements_on_external_id             (external_id) UNIQUE
#  index_topic_reply_limit_entitlements_on_group_id_and_starts_at  (group_id,starts_at)
#  index_topic_reply_limit_entitlements_on_user_id                 (user_id) UNIQUE
#
