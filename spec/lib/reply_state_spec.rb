# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::ReplyState do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    SiteSetting.topic_reply_limits_enabled = true
    group.add(user)
  end

  describe ".for" do
    it "returns the warning state at the configured threshold" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 20,
        warning_percentage: 80
      )
      DiscourseTopicReplyLimits::Usage.create!(user:, topic:, reply_count: 16)

      state = described_class.for(user:, topic:)

      expect(state).to include(reached: false, reply_count: 16)
      expect(state[:warnings]).to eq(
        [
          {
            reply_limit: 20,
            warning_percentage: 80,
            warning_at: 16,
            reply_count: 16,
            remaining: 4,
            reached: false,
            warning: true
          }
        ]
      )
    end

    it "rounds fractional warning thresholds up" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 7,
        warning_percentage: 80
      )
      DiscourseTopicReplyLimits::Usage.create!(user:, topic:, reply_count: 5)

      before_threshold = described_class.for(user:, topic:)
      DiscourseTopicReplyLimits::Usage.find_by(user:, topic:).update!(
        reply_count: 6
      )
      at_threshold = described_class.for(user:, topic:)

      expect(before_threshold[:warnings]).to be_empty
      expect(at_threshold[:warnings]).to contain_exactly(
        include(warning_at: 6, remaining: 1)
      )
    end

    it "marks an assignment reached without exposing a warning" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 2,
        warning_percentage: 50
      )
      DiscourseTopicReplyLimits::Usage.create!(user:, topic:, reply_count: 2)

      state = described_class.for(user:, topic:)

      expect(state[:reached]).to eq(true)
      expect(state[:warnings]).to be_empty
      expect(state[:assignments]).to contain_exactly(
        include(reached: true, remaining: 0, reply_count: 2)
      )
    end

    it "returns each matching group assignment independently" do
      second_group = Fabricate(:group)
      second_group.add(user)
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 5,
        warning_percentage: 80
      )
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group: second_group,
        reply_limit: 20,
        warning_percentage: 80
      )
      DiscourseTopicReplyLimits::Usage.create!(user:, topic:, reply_count: 5)

      state = described_class.for(user:, topic:)

      expect(state[:reached]).to eq(true)
      expect(state[:assignments]).to contain_exactly(
        include(reply_limit: 5, reached: true),
        include(reply_limit: 20, reached: false)
      )
    end

    it "returns no state when the setting is disabled" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 1,
        warning_percentage: 80
      )
      SiteSetting.topic_reply_limits_enabled = false

      expect(described_class.for(user:, topic:)).to be_nil
    end

    it "returns no state for staff, private messages, or unmatched users" do
      admin = Fabricate(:admin)
      private_message = Fabricate(:private_message_topic, user: user)
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 1,
        warning_percentage: 80
      )

      expect(described_class.for(user: admin, topic:)).to be_nil
      expect(described_class.for(user:, topic: private_message)).to be_nil
      expect(described_class.for(user: Fabricate(:user), topic:)).to be_nil
    end
  end

  describe ".reached?" do
    it "returns true at the reply limit" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 1,
        warning_percentage: 80
      )
      DiscourseTopicReplyLimits::Usage.create!(user:, topic:, reply_count: 1)

      expect(described_class.reached?(user:, topic:)).to eq(true)
    end
  end
end
