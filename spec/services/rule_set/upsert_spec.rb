# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::RuleSet::Upsert do
  subject(:result) { described_class.call(params:, guardian:) }

  fab!(:admin)
  fab!(:topic)
  fab!(:group)
  fab!(:second_group, :group)

  let(:guardian) { admin.guardian }
  let(:params) do
    {
      topic_id: topic.id,
      assignments: [
        { group_id: group.id, reply_limit: 5, warning_percentage: 80 },
        { group_id: second_group.id, reply_limit: 20, warning_percentage: 75 }
      ]
    }
  end

  describe ".call" do
    it "creates every group assignment" do
      expect { result }.to change { DiscourseTopicReplyLimits::Rule.count }.by(
        2
      )

      expect(
        DiscourseTopicReplyLimits::Rule
          .where(topic:)
          .order(:group_id)
          .pluck(:group_id, :reply_limit, :warning_percentage)
      ).to contain_exactly([group.id, 5, 80], [second_group.id, 20, 75])
    end

    it "updates assignments and removes omitted groups" do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 2,
        warning_percentage: 50
      )
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group: second_group,
        reply_limit: 3,
        warning_percentage: 60
      )
      replacement_group = Fabricate(:group)
      replacement_params = {
        topic_id: topic.id,
        assignments: [
          { group_id: group.id, reply_limit: 10, warning_percentage: 90 },
          {
            group_id: replacement_group.id,
            reply_limit: 30,
            warning_percentage: 70
          }
        ]
      }

      replacement = described_class.call(params: replacement_params, guardian:)

      expect(replacement).to run_successfully
      expect(
        DiscourseTopicReplyLimits::Rule.where(topic:).pluck(
          :group_id,
          :reply_limit,
          :warning_percentage
        )
      ).to contain_exactly([group.id, 10, 90], [replacement_group.id, 30, 70])
    end

    it "rejects duplicate groups" do
      params[:assignments] << {
        group_id: group.id,
        reply_limit: 10,
        warning_percentage: 70
      }

      expect(result).to fail_a_contract
    end

    it "rejects limits outside supported boundaries" do
      params[:assignments].first[:reply_limit] = 0
      params[:assignments].last[:warning_percentage] = 100

      expect(result).to fail_a_contract
    end

    it "fails when a group is missing" do
      params[:assignments].first[:group_id] = -1

      expect(result).to fail_to_find_a_model(:groups)
    end

    it "fails when the topic is missing" do
      params[:topic_id] = -1

      expect(result).to fail_to_find_a_model(:topic)
    end

    it "fails for a non-admin user" do
      non_admin_guardian = Fabricate(:user).guardian

      result = described_class.call(params:, guardian: non_admin_guardian)

      expect(result).to fail_a_policy(:can_manage_reply_limits)
    end
  end
end
