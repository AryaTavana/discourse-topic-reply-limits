# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class RuleCollection
    include ActiveModel::Model

    attr_accessor :topic, :rules
  end
end
