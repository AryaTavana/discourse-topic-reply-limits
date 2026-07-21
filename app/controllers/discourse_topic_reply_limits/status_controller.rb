# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class StatusController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def show
      topic = Topic.find_by(id: params[:topic_id], archetype: Archetype.default)
      raise Discourse::NotFound if topic.blank?

      guardian.ensure_can_see!(topic)
      state = ReplyState.for(user: current_user, topic:)
      render json: {
               reply_limit: state,
               can_create_post:
                 guardian.can_create?(Post, topic) &&
                   !state&.fetch(:reached, false)
             }
    end
  end
end
