# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::StatusController do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    SiteSetting.topic_reply_limits_enabled = true
    group.add(user)
    DiscourseTopicReplyLimits::Rule.create!(
      topic:,
      group:,
      reply_limit: 5,
      warning_percentage: 80
    )
  end

  describe "#show" do
    it "returns the current user's topic reply state" do
      DiscourseTopicReplyLimits::Usage.create!(
        user:,
        topic:,
        group:,
        period_start: DiscourseTopicReplyLimits::Calendar.period_start,
        monthly_allowance: 5,
        warning_percentage: 80,
        carried_in: 0,
        reply_count: 4
      )
      sign_in(user)

      get "/topic-reply-limits/topics/#{topic.id}/status.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["reply_limit"]).to include(
        "reached" => false,
        "reply_count" => 4,
        "next_credit_at" => be_present,
        "warnings" =>
          contain_exactly(include("remaining" => 1, "warning" => true))
      )
      expect(response.parsed_body["can_create_post"]).to eq(true)
    end

    it "rejects an anonymous request" do
      get "/topic-reply-limits/topics/#{topic.id}/status.json"

      expect(response.status).to be_in([302, 403, 404])
    end

    it "rejects a user who cannot see the topic" do
      private_group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: private_group)
      private_topic = Fabricate(:topic, category: private_category)
      sign_in(user)

      get "/topic-reply-limits/topics/#{private_topic.id}/status.json"

      expect(response.status).to be_in([403, 404])
    end

    it "makes the endpoint unavailable when disabled" do
      SiteSetting.topic_reply_limits_enabled = false
      sign_in(user)

      get "/topic-reply-limits/topics/#{topic.id}/status.json"

      expect(response.status).to eq(404)
    end
  end
end
