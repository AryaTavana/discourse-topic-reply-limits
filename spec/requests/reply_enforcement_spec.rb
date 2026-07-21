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
    DiscourseTopicReplyLimits::Usage
      .where(user: target_user, topic:, group:)
      .order(period_start: :desc)
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

    it "backfills replies already created in the current month" do
      create_reply(1)
      expect(current_usage).to be_nil
      create_rule(reply_limit: 2)

      create_reply(2)

      expect(response.status).to eq(200)
      expect(current_usage.reply_count).to eq(2)

      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "counts deleted historical replies when creating monthly usage" do
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

    it "adds the monthly allowance and carries unused replies forward" do
      create_rule(reply_limit: 2)
      create_reply(1)

      next_month =
        DiscourseTopicReplyLimits::Calendar.next_credit_at(
          DiscourseTopicReplyLimits::Calendar.period_start
        ) + 1.day

      freeze_time(next_month) do
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

    it "removes carryover at expiration and starts a new subscription fresh" do
      create_rule(reply_limit: 2)
      create_reply(1)
      group.remove(user)
      user.reload
      expect(
        DiscourseTopicReplyLimits::Usage.where(user:, group:)
      ).to be_empty

      return_month =
        DiscourseTopicReplyLimits::Calendar.next_credit_at(
          DiscourseTopicReplyLimits::Calendar.period_start
        ).next_month + 1.day

      freeze_time(return_month) do
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
          DiscourseTopicReplyLimits::Usage.where(
            user:,
            topic:,
            group:
          ).count
        ).to eq(1)
      end
    end

    it "resets usage when a subscription expires and restarts in the same month" do
      create_rule(reply_limit: 2)
      create_reply(1)
      group.remove(user)
      user.reload

      expect(
        DiscourseTopicReplyLimits::Usage.where(user:, group:)
      ).to be_empty

      # Simulate a frozen row left by the pre-reset release. A closed
      # membership interval must make reactivation discard it.
      DiscourseTopicReplyLimits::Usage.create!(
        user:,
        topic:,
        group:,
        period_start: DiscourseTopicReplyLimits::Calendar.period_start,
        monthly_allowance: 2,
        warning_percentage: 80,
        carried_in: 5,
        reply_count: 1
      )

      group.add(user)
      user.reload
      state = DiscourseTopicReplyLimits::ReplyState.for(user:, topic:)

      expect(state[:assignments]).to contain_exactly(
        include(
          monthly_reply_limit: 2,
          carried_in: 0,
          total_allowance: 2,
          reply_count: 0,
          remaining: 2
        )
      )

      create_reply(2)
      expect(response.status).to eq(200)
      create_reply(3)
      expect(response.status).to eq(200)
      create_reply(4)
      expect(response.status).to eq(422)
    end
  end
end
