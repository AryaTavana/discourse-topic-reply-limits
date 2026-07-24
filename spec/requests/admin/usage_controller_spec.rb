# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::Admin::UsageController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:second_user, :user)
  fab!(:topic)
  fab!(:group)

  before do
    SiteSetting.topic_reply_limits_enabled = true
    group.add(user)
    group.add(second_user)
    DiscourseTopicReplyLimits::Rule.create!(
      topic:,
      group:,
      reply_limit: 5,
      warning_percentage: 80
    )
  end

  it "lists current used and remaining balances for an admin" do
    DiscourseTopicReplyLimits::Usage.create!(
      user:,
      topic:,
      group:,
      period_start: DiscourseTopicReplyLimits::Calendar.period_start,
      monthly_allowance: 5,
      warning_percentage: 80,
      carried_in: 2,
      reply_count: 3,
      last_reply_at: 1.hour.ago
    )
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json"

    expect(response.status).to eq(200)
    record =
      response
        .parsed_body
        .fetch("usage_records")
        .find { |row| row.dig("user", "id") == user.id }
    expect(record).to include(
      "monthly_allowance" => 5,
      "carried_in" => 2,
      "total_allowance" => 7,
      "reply_count" => 3,
      "remaining" => 4,
      "reached" => false
    )
    expect(record.dig("topic", "title")).to eq(topic.title)
    expect(record.dig("group", "name")).to eq(group.name)
    expect(response.parsed_body["meta"]).to include(
      "total_count" => 2,
      "page" => 1,
      "has_more" => false,
      "query" => ""
    )
  end

  it "includes active members who have not used any replies" do
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json",
        params: {
          q: user.username
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["usage_records"]).to contain_exactly(
      include(
        "user" => include("id" => user.id, "username" => user.username),
        "monthly_allowance" => 5,
        "reply_count" => 0,
        "remaining" => 5
      )
    )
  end

  it "searches across users, topics, and groups and paginates results" do
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json",
        params: {
          q: topic.title,
          per_page: 1,
          page: 1
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["usage_records"].length).to eq(1)
    expect(response.parsed_body["meta"]).to include(
      "total_count" => 2,
      "start_index" => 1,
      "end_index" => 1,
      "has_previous" => false,
      "has_more" => true
    )

    get "/admin/plugins/discourse-topic-reply-limits/usage.json",
        params: {
          q: group.name,
          per_page: 1,
          page: 2
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["usage_records"].length).to eq(1)
    expect(response.parsed_body["meta"]).to include(
      "start_index" => 2,
      "end_index" => 2,
      "has_previous" => true,
      "has_more" => false
    )

    get "/admin/plugins/discourse-topic-reply-limits/usage.json",
        params: {
          q: group.name,
          per_page: 1,
          page: 99
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["meta"]).to include(
      "page" => 2,
      "start_index" => 2,
      "end_index" => 2
    )
  end

  it "does not report staff because their replies bypass limits" do
    group.add(admin)
    group.add(moderator)
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json"

    user_ids =
      response
        .parsed_body
        .fetch("usage_records")
        .map { |record| record.dig("user", "id") }
    expect(user_ids).to contain_exactly(user.id, second_user.id)
  end

  it "reports every matching group assignment independently" do
    second_group = Fabricate(:group)
    second_group.add(user)
    DiscourseTopicReplyLimits::Rule.create!(
      topic:,
      group: second_group,
      reply_limit: 20,
      warning_percentage: 80
    )
    DiscourseTopicReplyLimits::Usage.create!(
      user:,
      topic:,
      group: second_group,
      period_start: DiscourseTopicReplyLimits::Calendar.period_start,
      monthly_allowance: 20,
      warning_percentage: 80,
      carried_in: 0,
      reply_count: 4
    )
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json"

    records =
      response
        .parsed_body
        .fetch("usage_records")
        .select { |record| record.dig("user", "id") == user.id }
    expect(records).to contain_exactly(
      include(
        "group" => include("id" => group.id),
        "monthly_allowance" => 5,
        "remaining" => 5
      ),
      include(
        "group" => include("id" => second_group.id),
        "monthly_allowance" => 20,
        "reply_count" => 4,
        "remaining" => 16
      )
    )
  end

  it "removes expired subscription assignments from the report" do
    group.remove(user)
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/usage.json",
        params: {
          q: user.username
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["usage_records"]).to be_empty
    expect(response.parsed_body.dig("meta", "total_count")).to eq(0)
  end

  it "rejects moderators and anonymous requests" do
    sign_in(moderator)
    get "/admin/plugins/discourse-topic-reply-limits/usage.json"
    expect(response.status).to be_in([403, 404])

    sign_out
    get "/admin/plugins/discourse-topic-reply-limits/usage.json"
    expect(response.status).to be_in([302, 403, 404])
  end
end
