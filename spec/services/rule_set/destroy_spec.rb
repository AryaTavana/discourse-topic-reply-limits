# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::RuleSet::Destroy do
  subject(:result) do
    described_class.call(params: { topic_id: topic.id }, guardian:)
  end

  fab!(:admin)
  fab!(:topic)
  fab!(:group)
  fab!(:second_group, :group)

  let(:guardian) { admin.guardian }

  before do
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
  end

  describe ".call" do
    it "deletes all assignments for the topic" do
      expect { result }.to change {
        DiscourseTopicReplyLimits::Rule.where(topic:).count
      }.from(2).to(0)
      expect(result).to run_successfully
    end

    it "retains usage history" do
      usage =
        DiscourseTopicReplyLimits::Usage.create!(
          user: Fabricate(:user),
          topic:,
          reply_count: 3
        )

      result

      expect(usage.reload.reply_count).to eq(3)
    end

    it "fails for a non-admin user" do
      non_admin_guardian = Fabricate(:user).guardian

      result =
        described_class.call(
          params: {
            topic_id: topic.id
          },
          guardian: non_admin_guardian
        )

      expect(result).to fail_a_policy(:can_manage_reply_limits)
    end

    it "fails when the topic has no assignments" do
      DiscourseTopicReplyLimits::Rule.where(topic:).delete_all

      expect(result).to fail_to_find_a_model(:rules)
    end
  end
end
