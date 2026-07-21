# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class ReplyCreationTracker
    def self.record(post)
      return true unless countable_reply?(post)

      rules =
        (
          if post.user.staff?
            []
          else
            Rule.for_user_and_topic(post.user, post.topic_id)
          end
        )
      return true if rules.empty?

      Usage.with_locked_current_for_rules!(
        user: post.user,
        topic: post.topic,
        rules:
      ) do |usages|
        return false if usages.values.any? { |usage| usage.blank? || usage.remaining <= 0 }

        usages.each_value do |usage|
          usage.update!(
            reply_count: usage.reply_count + 1,
            last_reply_at: post.created_at || Time.zone.now
          )
        end
        true
      end
    end

    def self.countable_reply?(post)
      post.user.present? && post.topic.present? &&
        !post.topic.private_message? && post.post_number.to_i > 1 &&
        post.post_type == Post.types[:regular]
    end

    private_class_method :countable_reply?
  end
end
