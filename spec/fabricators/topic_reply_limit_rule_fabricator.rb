# frozen_string_literal: true

Fabricator(
  :topic_reply_limit_rule,
  class_name: "DiscourseTopicReplyLimits::Rule"
) do
  topic
  group
  reply_limit { 5 }
  warning_percentage { 80 }
end
