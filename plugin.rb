# frozen_string_literal: true

# name: discourse-topic-reply-limits
# about: Applies per-topic reply limits to selected Discourse groups.
# version: 1.0.3
# authors: Arya Tavana
# url: https://github.com/AryaTavana/discourse-topic-reply-limits
# required_version: 3.5.0

enabled_site_setting :topic_reply_limits_enabled

register_asset "stylesheets/common/topic-reply-limits.scss"
register_asset "stylesheets/admin/topic-reply-limits.scss", :admin

register_svg_icon "gauge-high"
register_svg_icon "triangle-exclamation"
register_svg_icon "circle-exclamation"

add_admin_route(
  "discourse_topic_reply_limits.admin.title",
  "discourse-topic-reply-limits",
  use_new_show_route: true
)

add_api_key_scope(
  :topic_reply_limits,
  {
    read_rules: {
      actions: %w[
        discourse_topic_reply_limits/admin/rule_sets#index
        discourse_topic_reply_limits/admin/rule_sets#show
      ]
    },
    manage_rules: {
      actions: %w[
        discourse_topic_reply_limits/admin/rule_sets#create
        discourse_topic_reply_limits/admin/rule_sets#update
        discourse_topic_reply_limits/admin/rule_sets#destroy
      ]
    }
  }
)

module ::DiscourseTopicReplyLimits
  PLUGIN_NAME = "discourse-topic-reply-limits"
end

require_relative "lib/discourse_topic_reply_limits/engine"

after_initialize do
  require_relative "lib/discourse_topic_reply_limits/reply_creation_tracker"
  require_relative "lib/discourse_topic_reply_limits/reply_state"

  add_to_class(:topic_view, :topic_reply_limit_state) do |user|
    @topic_reply_limit_states ||= {}
    @topic_reply_limit_states[
      user&.id
    ] ||= DiscourseTopicReplyLimits::ReplyState.for(user:, topic: topic)
  end

  add_to_serializer(:topic_view, :reply_limit) do
    object.topic_reply_limit_state(scope.user)
  end

  add_to_serializer(
    "TopicViewDetails",
    :can_create_post,
    respect_plugin_enabled: false
  ) do
    scope.can_create?(Post, object.topic) &&
      !object.topic_reply_limit_state(scope.user)&.fetch(:reached, false)
  end

  add_model_callback(:post, :before_create) do
    if SiteSetting.topic_reply_limits_enabled &&
         !DiscourseTopicReplyLimits::ReplyCreationTracker.record(self)
      errors.add(
        :base,
        I18n.t("discourse_topic_reply_limits.errors.limit_reached")
      )
      throw(:abort)
    end
  end

  add_model_callback(Group, :after_destroy) do
    DiscourseTopicReplyLimits::Rule.where(group_id: id).delete_all
  end

  add_model_callback(User, :after_destroy) do
    DiscourseTopicReplyLimits::Usage.where(user_id: id).delete_all
  end

  add_model_callback(Topic, :after_destroy) do
    DiscourseTopicReplyLimits::Rule.where(topic_id: id).delete_all
    DiscourseTopicReplyLimits::Usage.where(topic_id: id).delete_all
  end
end
