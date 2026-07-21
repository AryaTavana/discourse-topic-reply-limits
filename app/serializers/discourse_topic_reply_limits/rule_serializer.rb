# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class RuleSerializer < ::ApplicationSerializer
    attributes :id, :group_id, :group_name, :reply_limit, :warning_percentage

    def group_name
      object.group.name
    end
  end
end
