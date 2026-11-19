# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::Admin::EntitlementsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:second_user, :user)
  fab!(:group)

  fab!(:single_sign_on_record) do
    SingleSignOnRecord.create!(
      user:,
      external_id: "django-user-42",
      last_payload: ""
    )
  end

  let(:sync_params) do
    {
      entitlements: [
        {
          user_external_id: single_sign_on_record.external_id,
          entitlement_id: "subscription-501",
          group_name: group.name,
          starts_at: "2026-07-25T14:37:21Z",
          ends_at: "2026-10-25T14:37:21Z"
        }
      ]
    }
  end

  describe "#sync" do
    it "upserts an entitlement idempotently for an admin" do
      sign_in(admin)

      expect do
        put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
            params: sync_params
      end.to change { DiscourseTopicReplyLimits::Entitlement.count }.by(1)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: sync_params

      entitlement = DiscourseTopicReplyLimits::Entitlement.find_by!(user:)
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "success" => "OK",
        "synced" => 1,
        "revoked" => 0,
        "users_not_found" => []
      )
      expect(entitlement).to have_attributes(
        group_id: group.id,
        external_id: "django-subscription:subscription-501",
        starts_at: Time.zone.parse("2026-07-25T14:37:21Z"),
        ends_at: Time.zone.parse("2026-10-25T14:37:21Z")
      )
      expect(DiscourseTopicReplyLimits::Entitlement.where(user:).count).to eq(1)
    end

    it "revokes an existing entitlement" do
      DiscourseTopicReplyLimits::Entitlement.create!(
        user:,
        group:,
        external_id: "django-subscription:subscription-501",
        starts_at: 1.month.ago
      )
      sign_in(admin)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: {
            entitlements: [
              { user_external_id: single_sign_on_record.external_id }
            ]
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "synced" => 0,
        "revoked" => 1,
        "users_not_found" => []
      )
      entitlement = DiscourseTopicReplyLimits::Entitlement.find_by!(user:)
      expect(entitlement.revoked_at).to be_present
      expect(
        DiscourseTopicReplyLimits::Entitlement.current_for(user:, group:)
      ).to be_nil
    end

    it "records a tombstone when revoking before the first active sync" do
      group.add(user)
      sign_in(admin)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: {
            entitlements: [
              { user_external_id: single_sign_on_record.external_id }
            ]
          }

      entitlement = DiscourseTopicReplyLimits::Entitlement.find_by!(user:)
      expect(response.status).to eq(200)
      expect(entitlement).to be_revoked
      expect(entitlement.group_id).to be_nil
      expect(
        DiscourseTopicReplyLimits::Entitlement.current_for(user:, group:)
      ).to be_nil
    end

    it "rejects an unknown entitlement group without partial writes" do
      sign_in(admin)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: {
            entitlements: [
              sync_params[:entitlements].first.merge(
                group_name: "missing-subscription-group"
              )
            ]
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
      expect(DiscourseTopicReplyLimits::Entitlement.all).to be_empty
    end

    it "rejects multiple records for the same user before applying either" do
      sign_in(admin)
      duplicate_records =
        sync_params[:entitlements] +
          [sync_params[:entitlements].first.merge(entitlement_id: "subscription-502")]

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: { entitlements: duplicate_records }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
      expect(DiscourseTopicReplyLimits::Entitlement.all).to be_empty
    end

    it "rejects the same subscription ID assigned to multiple users" do
      second_sso_record =
        SingleSignOnRecord.create!(
          user: second_user,
          external_id: "django-user-43",
          last_payload: ""
        )
      sign_in(admin)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: {
            entitlements: [
              sync_params[:entitlements].first,
              sync_params[:entitlements].first.merge(
                user_external_id: second_sso_record.external_id
              )
            ]
          }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
      expect(DiscourseTopicReplyLimits::Entitlement.all).to be_empty
    end

    it "reports an unknown Discourse Connect user" do
      sign_in(admin)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: {
            entitlements: [
              {
                user_external_id: "missing-django-user",
                entitlement_id: "subscription-999",
                group_name: group.name,
                starts_at: "2026-07-25T14:37:21Z"
              }
            ]
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "synced" => 0,
        "revoked" => 0,
        "users_not_found" => ["missing-django-user"]
      )
      expect(DiscourseTopicReplyLimits::Entitlement.all).to be_empty
    end

    it "rejects a moderator" do
      sign_in(moderator)

      put "/admin/plugins/discourse-topic-reply-limits/entitlements/sync.json",
          params: sync_params

      expect(response.status).to be_in([403, 404])
      expect(DiscourseTopicReplyLimits::Entitlement.all).to be_empty
    end
  end
end
