# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::Admin::RuleSetsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:topic)
  fab!(:group)
  fab!(:second_group, :group)

  let(:rule_set_params) do
    {
      rule_set: {
        topic_id: topic.id,
        assignments: [
          { group_id: group.id, reply_limit: 5, warning_percentage: 80 },
          { group_id: second_group.id, reply_limit: 20, warning_percentage: 75 }
        ]
      }
    }
  end

  describe "#index" do
    before do
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 5,
        warning_percentage: 80
      )
    end

    it "lists topic rule sets for an admin" do
      sign_in(admin)

      get "/admin/plugins/discourse-topic-reply-limits/rule-sets.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["rule_sets"]).to contain_exactly(
        include(
          "topic_id" => topic.id,
          "topic_title" => topic.title,
          "assignments" =>
            contain_exactly(
              include(
                "group_id" => group.id,
                "reply_limit" => 5,
                "warning_percentage" => 80
              )
            )
        )
      )
    end

    it "rejects a moderator" do
      sign_in(moderator)

      get "/admin/plugins/discourse-topic-reply-limits/rule-sets.json"

      expect(response.status).to be_in([403, 404])
    end

    it "rejects an anonymous request" do
      get "/admin/plugins/discourse-topic-reply-limits/rule-sets.json"

      expect(response.status).to be_in([302, 403, 404])
    end
  end

  describe "#create" do
    before { sign_in(admin) }

    it "creates a topic rule set" do
      expect do
        post "/admin/plugins/discourse-topic-reply-limits/rule-sets.json",
             params: rule_set_params
      end.to change { DiscourseTopicReplyLimits::Rule.count }.by(2)

      expect(response.status).to eq(201)
      expect(response.parsed_body["rule_set"]["topic_id"]).to eq(topic.id)
    end

    it "returns contract errors for duplicate groups" do
      rule_set_params[:rule_set][:assignments] << {
        group_id: group.id,
        reply_limit: 10,
        warning_percentage: 70
      }

      post "/admin/plugins/discourse-topic-reply-limits/rule-sets.json",
           params: rule_set_params

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
      expect(DiscourseTopicReplyLimits::Rule.where(topic:)).to be_empty
    end

    it "rejects an unknown group without creating rules" do
      rule_set_params[:rule_set][:assignments].first[:group_id] = -1

      post "/admin/plugins/discourse-topic-reply-limits/rule-sets.json",
           params: rule_set_params

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("discourse_topic_reply_limits.errors.invalid_groups")
      )
      expect(DiscourseTopicReplyLimits::Rule.where(topic:)).to be_empty
    end
  end

  describe "#update" do
    before do
      sign_in(admin)
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 5,
        warning_percentage: 80
      )
    end

    it "replaces the assignments for the route topic" do
      update_params = {
        rule_set: {
          topic_id: Fabricate(:topic).id,
          assignments: [
            {
              group_id: second_group.id,
              reply_limit: 40,
              warning_percentage: 90
            }
          ]
        }
      }

      put "/admin/plugins/discourse-topic-reply-limits/rule-sets/#{topic.id}.json",
          params: update_params

      expect(response.status).to eq(200)
      expect(
        DiscourseTopicReplyLimits::Rule.where(topic:).pluck(
          :group_id,
          :reply_limit,
          :warning_percentage
        )
      ).to eq([[second_group.id, 40, 90]])
    end
  end

  describe "#destroy" do
    before do
      sign_in(admin)
      DiscourseTopicReplyLimits::Rule.create!(
        topic:,
        group:,
        reply_limit: 5,
        warning_percentage: 80
      )
    end

    it "deletes the topic rule set" do
      expect do
        delete "/admin/plugins/discourse-topic-reply-limits/rule-sets/#{topic.id}.json"
      end.to change {
        DiscourseTopicReplyLimits::Rule.where(topic:).count
      }.from(1).to(0)

      expect(response.status).to eq(204)
    end

    it "returns not found for a topic without rules" do
      DiscourseTopicReplyLimits::Rule.where(topic:).delete_all

      delete "/admin/plugins/discourse-topic-reply-limits/rule-sets/#{topic.id}.json"

      expect(response.status).to eq(404)
    end
  end
end
