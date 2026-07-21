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

  describe "#create" do
    it "allows replies through the limit and blocks the next reply" do
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
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(2)
    end

    it "disables topic replies after the limit is reached" do
      create_rule(reply_limit: 1)
      create_reply(1)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["details"]["can_create_post"]).to eq(false)
      expect(response.parsed_body["reply_limit"]).to include(
        "reached" => true,
        "reply_count" => 1
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
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(2)
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
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(1)

      create_reply(2)
      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "backfills historical replies before allowing a new reply" do
      create_reply(1)
      expect(DiscourseTopicReplyLimits::Usage.find_by(user:, topic:)).to be_nil
      create_rule(reply_limit: 2)

      create_reply(2)

      expect(response.status).to eq(200)
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(2)

      create_reply(3)
      expect(response.status).to eq(422)
    end

    it "counts deleted historical replies when creating usage" do
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

    it "bypasses all rules for staff" do
      sign_in(admin)
      create_rule(reply_limit: 1, target_user: admin)

      create_reply(1)
      expect(response.status).to eq(200)
      create_reply(2)

      expect(response.status).to eq(200)
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(
          user: admin,
          topic:
        ).reply_count
      ).to eq(2)
    end

    it "counts replies before a user joins a limited group" do
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
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(2)

      group.add(user)
      user.reload
      create_reply(3)

      expect(response.status).to eq(422)
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
      expect(
        DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).reply_count
      ).to eq(1)
    end
  end
end
