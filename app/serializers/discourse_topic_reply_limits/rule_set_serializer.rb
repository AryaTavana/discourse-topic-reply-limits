# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class RuleSetSerializer < ::ApplicationSerializer
    attributes :topic_id, :topic_title, :topic_slug, :topic_url, :assignments

    def topic_id
      object.topic.id
    end

    def topic_title
      object.topic.title
    end

    def topic_slug
      object.topic.slug
    end

    def topic_url
      object.topic.url
    end

    def assignments
      object.rules.map { |rule| RuleSerializer.new(rule, root: false).as_json }
    end
  end
end
