# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::RuleSet::Upsert do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(**attributes) }

    let(:attributes) { { topic_id: 1, assignments: [valid_assignment] } }
    let(:valid_assignment) do
      {
        group_id: 1,
        reply_limit: 5,
        warning_percentage: 80,
        carryover_limit: 3
      }
    end

    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:assignments) }

    context "with an assignment contract" do
      subject(:assignment_contract) do
        assignment_contract_class.new(**valid_assignment)
      end

      let(:assignment_contract_class) do
        described_class.attribute_types.fetch("assignments").contract_class
      end

      it { is_expected.to validate_presence_of(:group_id) }

      it do
        is_expected.to allow_values(
          1,
          DiscourseTopicReplyLimits::Rule::MAX_REPLY_LIMIT
        ).for(:reply_limit)
      end

      it do
        is_expected.not_to allow_values(
          0,
          DiscourseTopicReplyLimits::Rule::MAX_REPLY_LIMIT + 1
        ).for(:reply_limit)
      end

      it { is_expected.to allow_values(1, 99).for(:warning_percentage) }
      it { is_expected.not_to allow_values(0, 100).for(:warning_percentage) }

      it do
        is_expected.to allow_values(
          nil,
          0,
          DiscourseTopicReplyLimits::Rule::MAX_REPLY_LIMIT
        ).for(:carryover_limit)
      end

      it do
        is_expected.not_to allow_values(
          -1,
          DiscourseTopicReplyLimits::Rule::MAX_REPLY_LIMIT + 1
        ).for(:carryover_limit)
      end
    end

    context "with duplicate group assignments" do
      let(:attributes) do
        {
          topic_id: 1,
          assignments: [valid_assignment, valid_assignment.deep_dup]
        }
      end

      it "adds a duplicate-groups error" do
        expect(contract).not_to be_valid
        expect(contract.errors.details[:assignments]).to contain_exactly(
          error: :duplicate_groups
        )
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:actor, :admin)
    fab!(:topic)
    fab!(:group)
    fab!(:second_group, :group)
    fab!(:replacement_group, :group)

    fab!(:existing_rule) do
      Fabricate(
        :topic_reply_limit_rule,
        topic:,
        group:,
        reply_limit: 2,
        warning_percentage: 50
      )
    end

    fab!(:omitted_rule) do
      Fabricate(
        :topic_reply_limit_rule,
        topic:,
        group: second_group,
        reply_limit: 3,
        warning_percentage: 60
      )
    end

    let(:params) { { topic_id:, assignments: } }
    let(:dependencies) { { guardian: actor.guardian } }
    let(:topic_id) { topic.id }

    let(:assignments) do
      [
        {
          group_id: group.id,
          reply_limit:,
          warning_percentage: 90,
          carryover_limit: 4
        },
        {
          group_id: replacement_group_id,
          reply_limit: 30,
          warning_percentage: 70,
          carryover_limit: nil
        }
      ]
    end

    let(:reply_limit) { 10 }
    let(:replacement_group_id) { replacement_group.id }

    context "when the contract is invalid" do
      let(:reply_limit) { 0 }

      it { is_expected.to fail_a_contract }
    end

    context "when the actor is not an admin" do
      fab!(:actor, :user)

      it { is_expected.to fail_a_policy(:can_manage_reply_limits) }
    end

    context "when the topic is missing" do
      let(:topic_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when a group is missing" do
      let(:replacement_group_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:groups) }
    end

    context "when all steps pass" do
      fab!(:member, :user)

      before { replacement_group.add(member) }

      it { is_expected.to run_successfully }

      it "replaces the rules and records revisions", :aggregate_failures do
        expect { result }.not_to change {
          DiscourseTopicReplyLimits::Rule.count
        }
        expect(
          DiscourseTopicReplyLimits::Rule.where(topic:).pluck(
            :group_id,
            :reply_limit,
            :warning_percentage,
            :carryover_limit
          )
        ).to contain_exactly(
          [group.id, 10, 90, 4],
          [replacement_group.id, 30, 70, nil]
        )
        expect(
          DiscourseTopicReplyLimits::RuleRevision.where(
            topic_id: topic.id
          ).pluck(
            :group_id,
            :active,
            :reply_limit,
            :warning_percentage,
            :carryover_limit
          )
        ).to contain_exactly(
          [group.id, true, 2, 50, nil],
          [group.id, true, 10, 90, 4],
          [second_group.id, true, 3, 60, nil],
          [second_group.id, false, nil, nil, nil],
          [replacement_group.id, true, 30, 70, nil]
        )
      end

      it "bootstraps current membership periods" do
        expect { result }.to change {
          DiscourseTopicReplyLimits::MembershipPeriod.where(
            group_id: replacement_group.id,
            ends_at: nil
          ).count
        }.by(1)
      end

      it "logs the rule-set change", :aggregate_failures do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "upsert_topic_reply_limits"
          ).count
        }.by(1)

        history = UserHistory.order(:id).last
        expect(history).to have_attributes(
          acting_user_id: actor.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "upsert_topic_reply_limits",
          subject: topic.title,
          topic_id: topic.id
        )
        expect(history.details).to eq(
          "group_limits: #{group.id}:10@90%/carry:4," \
            "#{replacement_group.id}:30@70%/carry:unlimited"
        )
      end
    end
  end
end
