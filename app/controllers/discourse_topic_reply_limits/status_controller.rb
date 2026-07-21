# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class StatusController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def show
      topic = Topic.find_by(id: params[:topic_id], archetype: Archetype.default)
      raise Discourse::NotFound if topic.blank?

      guardian.ensure_can_see!(topic)
      render json: { reply_limit: ReplyState.for(user: current_user, topic:) }
    end
  end
end
