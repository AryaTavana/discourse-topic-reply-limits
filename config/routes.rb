# frozen_string_literal: true

Discourse::Application.routes.draw do
  scope "/admin/plugins/discourse-topic-reply-limits",
        constraints: AdminConstraint.new,
        defaults: {
          format: :json
        },
        as: :topic_reply_limits do
    get "/rule-sets" => "discourse_topic_reply_limits/admin/rule_sets#index"
    get "/rule-sets/:topic_id" =>
          "discourse_topic_reply_limits/admin/rule_sets#show"
    post "/rule-sets" => "discourse_topic_reply_limits/admin/rule_sets#create"
    put "/rule-sets/:topic_id" =>
          "discourse_topic_reply_limits/admin/rule_sets#update"
    delete "/rule-sets/:topic_id" =>
             "discourse_topic_reply_limits/admin/rule_sets#destroy"
  end

  get "/topic-reply-limits/topics/:topic_id/status" =>
        "discourse_topic_reply_limits/status#show",
      :as => :topic_reply_limit_status,
      :defaults => {
        format: :json
      }
end
