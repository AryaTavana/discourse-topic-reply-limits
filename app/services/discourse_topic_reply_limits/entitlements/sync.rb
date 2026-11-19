# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module Entitlements
    class Sync
      include Service::Base

      MAX_BATCH_SIZE = 500

      params do
        attribute :entitlements, :array do
          attribute :user_external_id, :string
          attribute :entitlement_id, :string
          attribute :group_name, :string
          attribute :starts_at, :datetime
          attribute :ends_at, :datetime

          validates :user_external_id, presence: true
          validates :user_external_id, length: { maximum: 255 }
          validates :entitlement_id, length: { maximum: 200 }, allow_blank: true
          validates :group_name, length: { maximum: 100 }, allow_blank: true
          validates :entitlement_id,
                    :group_name,
                    :starts_at,
                    presence: true,
                    unless: :revocation?
          validate :ends_after_start

          def revocation?
            entitlement_id.blank?
          end

          def ends_after_start
            return if revocation? || ends_at.blank? || starts_at.blank?
            return if ends_at > starts_at

            errors.add(:ends_at, "must be after the entitlement start")
          end
        end

        validates :entitlements,
                  presence: true,
                  length: {
                    maximum: MAX_BATCH_SIZE
                  }
        validate :entitlement_records_are_unique

        def entitlement_records_are_unique
          records = entitlements.to_a
          duplicate_user =
            records.map(&:user_external_id).compact.tally.any? do |_id, count|
              count > 1
            end
          if duplicate_user
            errors.add(:entitlements, :duplicate_users)
          end

          entitlement_ids =
            records.filter_map(&:entitlement_id).reject(&:blank?)
          if entitlement_ids.tally.any? { |_id, count| count > 1 }
            errors.add(:entitlements, :duplicate_entitlements)
          end
        end
      end

      policy :can_sync_entitlements
      transaction { step :sync_entitlements }

      private

      def can_sync_entitlements(guardian:)
        guardian.is_admin?
      end

      def sync_entitlements(params:)
        context[:result] = { synced: 0, revoked: 0, users_not_found: [] }
        sso_records =
          SingleSignOnRecord
            .includes(:user)
            .where(external_id: params.entitlements.map(&:user_external_id))
            .index_by(&:external_id)
        resolved =
          params.entitlements.map do |item|
            [item, sso_records[item.user_external_id]&.user]
          end

        resolved.each do |item, user|
          unless user
            context[:result][:users_not_found] << item.user_external_id
          end
        end

        resolved
          .select { |_item, user| user }
          .sort_by { |_item, user| user.id }
          .each do |item, user|
            if item.revocation?
              revoke!(user)
              context[:result][:revoked] += 1
              next
            end

            group = Group.find_by(name: item.group_name)
            unless group
              context[:error_message] = I18n.t(
                "discourse_topic_reply_limits.errors.entitlement_group_missing",
                group: item.group_name
              )
              fail!(context[:error_message])
            end

            upsert!(user:, group:, item:)
            context[:result][:synced] += 1
          end
      end

      def revoke!(user)
        entitlement =
          DiscourseTopicReplyLimits::Entitlement.find_or_initialize_by(
            user_id: user.id
          )
        group_ids = [
          entitlement.group_id,
          *GroupUser.where(user_id: user.id).pluck(:group_id)
        ].compact

        CycleUsage.acquire_user_topic_locks!(
          DiscourseTopicReplyLimits::Entitlement.usage_lock_pairs(
            user_id: user.id,
            group_ids:
          )
        )
        revoked_at = Time.zone.now
        entitlement.update!(
          external_id:
            entitlement.external_id.presence || "revoked-user:#{user.id}",
          starts_at: entitlement.starts_at || revoked_at,
          revoked_at:
        )
      end

      def upsert!(user:, group:, item:)
        external_id = "django-subscription:#{item.entitlement_id}"
        transferred_entitlement =
          DiscourseTopicReplyLimits::Entitlement
            .where(external_id:)
            .where.not(user_id: user.id)
            .first
        entitlement =
          DiscourseTopicReplyLimits::Entitlement.find_or_initialize_by(
            user_id: user.id
          )
        lock_pairs =
          DiscourseTopicReplyLimits::Entitlement.usage_lock_pairs(
            user_id: user.id,
            group_ids: [entitlement.group_id, group.id].compact
          )
        if transferred_entitlement
          lock_pairs +=
            DiscourseTopicReplyLimits::Entitlement.usage_lock_pairs(
              user_id: transferred_entitlement.user_id,
              group_ids: [transferred_entitlement.group_id]
            )
        end
        CycleUsage.acquire_user_topic_locks!(lock_pairs)

        transferred_entitlement.destroy! if transferred_entitlement
        entitlement.update!(
          group:,
          external_id:,
          starts_at: item.starts_at,
          ends_at: item.ends_at,
          revoked_at: nil
        )
      end
    end
  end
end
