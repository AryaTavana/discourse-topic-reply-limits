# frozen_string_literal: true

require "digest"

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
      return true unless tracked_topic_for_user?(post, rules)

      acquire_transaction_lock(post)
      usage = Usage.locked_for_reply!(user: post.user, topic: post.topic)
      if rules.any? { |rule| usage.reply_count >= rule.reply_limit }
        return false
      end

      usage.update!(
        reply_count: usage.reply_count + 1,
        last_reply_at: post.created_at || Time.zone.now
      )
      true
    end

    def self.countable_reply?(post)
      post.user.present? && post.topic.present? &&
        !post.topic.private_message? && post.post_number.to_i > 1 &&
        post.post_type == Post.types[:regular]
    end

    def self.tracked_topic_for_user?(post, rules)
      rules.present? || Rule.where(topic_id: post.topic_id).exists? ||
        Usage.where(user_id: post.user_id, topic_id: post.topic_id).exists?
    end

    def self.acquire_transaction_lock(post)
      key =
        Digest::SHA256.digest(
          "topic-reply-limits:#{post.topic_id}:#{post.user_id}"
        ).unpack1("q>")
      DB.exec("SELECT pg_advisory_xact_lock(?)", key)
    end

    private_class_method :countable_reply?,
                         :tracked_topic_for_user?,
                         :acquire_transaction_lock
  end
end
