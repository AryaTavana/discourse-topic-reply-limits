# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::ReplyState do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    SiteSetting.topic_reply_limits_enabled = true
    group.add(user)
  end

  def create_usage(
    target_group: group,
    monthly_allowance:,
    reply_count:,
    carried_in: 0,
    warning_percentage: 80,
    period_start: DiscourseTopicReplyLimits::Calendar.period_start
  )
    DiscourseTopicReplyLimits::Usage.create!(
      user:,
      topic:,
      group: target_group,
      period_start:,
      monthly_allowance:,
      warning_percentage:,
      carried_in:,
      reply_count:
    )
  end

  describe ".for" do
    it "returns the warning state at the configured threshold" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 20,
        warning_percentage: 80
      )
      create_usage(monthly_allowance: 20, reply_count: 16)

      state = described_class.for(user:, topic:)

      expect(state).to include(
        reached: false,
        reply_count: 16,
        next_credit_at: be_present
      )
      expect(state[:warnings]).to eq(
        [
          {
            reply_limit: 20,
            monthly_reply_limit: 20,
            carried_in: 0,
            total_allowance: 20,
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

    it "calculates warnings against the allowance plus carryover" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 5,
        warning_percentage: 80
      )
      create_usage(
        monthly_allowance: 5,
        carried_in: 2,
        reply_count: 6
      )

      state = described_class.for(user:, topic:)

      expect(state[:warnings]).to contain_exactly(
        include(
          total_allowance: 7,
          warning_at: 6,
          remaining: 1,
          carried_in: 2
        )
      )
    end

    it "marks an assignment reached without exposing a warning" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 2,
        warning_percentage: 50
      )
      create_usage(
        monthly_allowance: 2,
        reply_count: 2,
        warning_percentage: 50
      )

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
      create_usage(monthly_allowance: 5, reply_count: 5)
      create_usage(
        target_group: second_group,
        monthly_allowance: 20,
        reply_count: 5
      )

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
    it "returns true at the current monthly allowance" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 1,
        warning_percentage: 80
      )
      create_usage(monthly_allowance: 1, reply_count: 1)

      expect(described_class.reached?(user:, topic:)).to eq(true)
    end
  end
end
