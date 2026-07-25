# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:post).topic }
  fab!(:group)

  before do
    SiteSetting.topic_reply_limits_enabled = true
    group.add(user)
    sign_in(user)
  end

  def create_rule(reply_limit:, warning_percentage: 80, target_user: user)
    group.add(target_user)
    DiscourseTopicReplyLimits::Rule.create!(
      topic:,
      group:,
      reply_limit:,
      warning_percentage:
    )
  end

  def create_reply(number)
    post "/posts.json",
         params: {
           topic_id: topic.id,
           raw: "Production reply limit test message number #{number}"
         }
  end

  def current_usage(target_user: user)
    DiscourseTopicReplyLimits::CycleUsage
      .where(user: target_user, topic:, group:)
      .order(cycle_started_at: :desc)
      .first
  end

  describe "#create" do
    it "allows replies through the monthly allowance and blocks the next reply" do
      create_rule(reply_limit: 2)

      create_reply(1)
      expect(response.status).to eq(200)
      create_reply(2)
      expect(response.status).to eq(200)
      create_reply(3)

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_topic_reply_limits.errors.limit_reached")
      )
      expect(current_usage.reply_count).to eq(2)
    end

    it "applies a decreased rule immediately to the active cycle" do
      create_rule(reply_limit: 8)
      create_reply(1)
      create_reply(2)

      result =
        DiscourseTopicReplyLimits::RuleSet::Upsert.call(
          params: {
            topic_id: topic.id,
            assignments: [
              { group_id: group.id, reply_limit: 2, warning_percentage: 80 }
            ]
          },
          guardian: admin.guardian
        )

      expect(result).to run_successfully
      state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)
      expect(state[:assignments]).to contain_exactly(
        include(
          monthly_reply_limit: 2,
          total_allowance: 2,
          reply_count: 2,
          remaining: 0,
          reached: true
        )
      )
      expect(current_usage.reload.monthly_allowance).to eq(2)

      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "uses the edited rule for a user whose cycle was not materialized yet" do
      create_rule(reply_limit: 8)

      result =
        DiscourseTopicReplyLimits::RuleSet::Upsert.call(
          params: {
            topic_id: topic.id,
            assignments: [
              { group_id: group.id, reply_limit: 2, warning_percentage: 80 }
            ]
          },
          guardian: admin.guardian
        )

      expect(result).to run_successfully
      state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)
      expect(state[:assignments]).to contain_exactly(
        include(
          monthly_reply_limit: 2,
          total_allowance: 2,
          reply_count: 0,
          remaining: 2
        )
      )
    end

    it "disables topic replies after the allowance is used" do
      create_rule(reply_limit: 1)
      create_reply(1)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["details"]["can_create_post"]).to eq(false)
      expect(response.parsed_body["reply_limit"]).to include(
        "reached" => true,
        "reply_count" => 1,
        "next_credit_at" => be_present
      )
    end

    it "publishes the warning state at the configured threshold" do
      create_rule(reply_limit: 5, warning_percentage: 80)

      4.times { |index| create_reply(index + 1) }
      state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

      expect(state[:warnings]).to contain_exactly(
        include(reply_count: 4, remaining: 1, warning_percentage: 80)
      )
    end

    it "does not decrement usage when a reply is deleted" do
      create_rule(reply_limit: 2)
      create_reply(1)
      deleted_reply = Post.find(response.parsed_body["id"])

      PostDestroyer.new(
        Discourse.system_user,
        deleted_reply,
        context: "spec"
      ).destroy
      create_reply(2)
      create_reply(3)

      expect(response.status).to eq(422)
      expect(current_usage.reply_count).to eq(2)
    end

    it "does not increment usage when a reply is edited" do
      create_rule(reply_limit: 2)
      create_reply(1)
      reply_id = response.parsed_body["id"]

      put "/posts/#{reply_id}.json",
          params: {
            post: {
              raw:
                "This existing reply was edited without creating a new reply",
              edit_reason: "spec"
            }
          }

      expect(response.status).to eq(200)
      expect(current_usage.reply_count).to eq(1)

      create_reply(2)
      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "backfills replies created in the subscription cycle" do
      create_reply(1)
      expect(current_usage).to be_nil
      create_rule(reply_limit: 2)

      create_reply(2)

      expect(response.status).to eq(200)
      expect(current_usage.reply_count).to eq(2)

      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "counts deleted replies when backfilling cycle usage" do
      create_reply(1)
      historical_reply = Post.find(response.parsed_body["id"])
      PostDestroyer.new(
        Discourse.system_user,
        historical_reply,
        context: "spec"
      ).destroy
      create_rule(reply_limit: 1)

      create_reply(2)

      expect(response.status).to eq(422)
      expect(
        Post.with_deleted.find(historical_reply.id).deleted_at
      ).to be_present
    end

    it "bypasses all rules and accounting for staff" do
      sign_in(admin)
      create_rule(reply_limit: 1, target_user: admin)

      create_reply(1)
      expect(response.status).to eq(200)
      create_reply(2)

      expect(response.status).to eq(200)
      expect(current_usage(target_user: admin)).to be_nil
    end

    it "does not count replies from before subscription membership starts" do
      group.remove(user)
      user.reload
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 2,
        warning_percentage: 80
      )

      create_reply(1)
      create_reply(2)
      expect(current_usage).to be_nil

      group.add(user)
      user.reload
      expect(
        DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)
      ).to include(reached: false, reply_count: 0)
      create_reply(3)
      expect(response.status).to eq(200)
      create_reply(4)
      expect(response.status).to eq(200)
      create_reply(5)

      expect(response.status).to eq(422)
      expect(current_usage.reply_count).to eq(2)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_topic_reply_limits.errors.limit_reached")
      )
    end

    it "does not enforce rules when the setting is disabled" do
      create_rule(reply_limit: 1)
      create_reply(1)
      SiteSetting.topic_reply_limits_enabled = false

      create_reply(2)

      expect(response.status).to eq(200)
      expect(current_usage.reply_count).to eq(1)
    end

    it "adds the allowance and carries unused replies forward" do
      create_rule(reply_limit: 2)
      create_reply(1)

      entitlement =
        DiscourseTopicReplyLimits::Entitlement.current_for(user:, group:)
      next_cycle = entitlement.starts_at.advance(months: 1) + 1.second

      freeze_time(next_cycle) do
        state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)
        expect(state[:assignments]).to contain_exactly(
          include(
            monthly_reply_limit: 2,
            carried_in: 1,
            total_allowance: 3,
            reply_count: 0,
            remaining: 3
          )
        )

        3.times do |index|
          create_reply(index + 2)
          expect(response.status).to eq(200)
        end
        create_reply(5)
        expect(response.status).to eq(422)
      end
    end

    it "starts a new group membership with a fresh allowance" do
      create_rule(reply_limit: 2)
      create_reply(1)
      old_external_id = current_usage.entitlement_external_id

      group.remove(user)
      user.reload
      return_time = 2.months.from_now

      freeze_time(return_time) do
        group.add(user)
        user.reload
        state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

        expect(state[:assignments]).to contain_exactly(
          include(
            monthly_reply_limit: 2,
            carried_in: 0,
            total_allowance: 2,
            reply_count: 0
          )
        )
        expect(
          DiscourseTopicReplyLimits::CycleUsage.where(
            user:,
            topic:,
            group:
          ).pluck(:entitlement_external_id)
        ).to contain_exactly(
          old_external_id,
          match(/\Amembership-period:\d+\z/)
        )
      end
    end

    it "starts a new external entitlement with a fresh allowance" do
      purchased_at = 1.day.ago
      entitlement =
        DiscourseTopicReplyLimits::Entitlement.create!(
          user:,
          group:,
          external_id: "django-subscription:first",
          starts_at: purchased_at
        )
      create_rule(reply_limit: 2)
      create_reply(1)
      first_usage = current_usage

      renewed_at = 1.hour.from_now
      freeze_time(renewed_at) do
        entitlement.update!(
          external_id: "django-subscription:second",
          starts_at: renewed_at,
          ends_at: nil
        )

        state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

        expect(state[:assignments]).to contain_exactly(
          include(
            carried_in: 0,
            total_allowance: 2,
            reply_count: 0,
            remaining: 2,
            cycle_started_at: renewed_at
          )
        )
        expect(first_usage.reload.reply_count).to eq(1)
        expect(current_usage.entitlement_external_id).to eq(
          "django-subscription:second"
        )
      end
    end

    it "does not grant credit at the exact subscription end" do
      subscription_start = Time.zone.parse("2026-07-25 14:37:21 UTC")
      subscription_end = Time.zone.parse("2026-08-25 14:37:21 UTC")

      freeze_time(subscription_end - 1.second) do
        DiscourseTopicReplyLimits::Entitlement.create!(
          user:,
          group:,
          external_id: "django-subscription:one-month",
          starts_at: subscription_start,
          ends_at: subscription_end
        )
        create_rule(reply_limit: 2)

        state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

        expect(state).to include(
          reached: false,
          next_credit_at: nil,
          subscription_ends_at: subscription_end,
          period_start: subscription_start
        )
      end

      freeze_time(subscription_end) do
        state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

        expect(state).to include(
          reached: true,
          unavailable: true,
          next_credit_at: nil
        )
        expect(
          DiscourseTopicReplyLimits::CycleUsage.where(
            user:,
            topic:,
            group:,
            cycle_started_at: subscription_end
          )
        ).to be_empty
      end
    end

    it "blocks an expired entitlement before group removal" do
      DiscourseTopicReplyLimits::Entitlement.create!(
        user:,
        group:,
        external_id: "django-subscription:expired",
        starts_at: 2.months.ago,
        ends_at: 1.second.ago
      )
      create_rule(reply_limit: 2)

      create_reply(1)

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_topic_reply_limits.errors.limit_reached")
      )
    end
  end
end
