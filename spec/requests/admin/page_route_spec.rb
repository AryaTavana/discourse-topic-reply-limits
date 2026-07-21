# frozen_string_literal: true

RSpec.describe "Topic reply limits admin page" do
  fab!(:admin)
  fab!(:moderator)

  it "serves the admin application shell for the rules page" do
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/reply-limits"

    expect(response.status).to eq(200)
    expect(response.media_type).to eq("text/html")
  end

  it "serves the admin application shell for nested editor pages" do
    sign_in(admin)

    get "/admin/plugins/discourse-topic-reply-limits/reply-limits/new"

    expect(response.status).to eq(200)
    expect(response.media_type).to eq("text/html")
  end

  it "does not expose the admin page to moderators" do
    sign_in(moderator)

    get "/admin/plugins/discourse-topic-reply-limits/reply-limits"

    expect(response.status).to eq(404)
  end
end
