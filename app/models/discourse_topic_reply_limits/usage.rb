# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class Usage < ::ActiveRecord::Base
    self.table_name = "topic_reply_limit_usages"

    belongs_to :topic, -> { with_deleted }
    belongs_to :user

    validates :user_id, uniqueness: { scope: :topic_id }
    validates :reply_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              }

    def self.count_for(user:, topic:)
      find_by(user_id: user.id, topic_id: topic.id)&.reply_count ||
        historical_reply_count(user:, topic:)
    end

    def self.locked_for_reply!(user:, topic:)
      usage = lock.find_by(user_id: user.id, topic_id: topic.id)
      return usage if usage

      reply_count, last_reply_at = historical_reply_stats(user:, topic:)
      create!(user:, topic:, reply_count:, last_reply_at:)
    end

    def self.historical_reply_count(user:, topic:)
      historical_replies(user:, topic:).count
    end

    def self.historical_reply_stats(user:, topic:)
      replies = historical_replies(user:, topic:)
      [replies.count, replies.maximum(:created_at)]
    end

    def self.historical_replies(user:, topic:)
      Post
        .with_deleted
        .where(
          user_id: user.id,
          topic_id: topic.id,
          post_type: Post.types[:regular]
        )
        .where.not(post_number: 1)
    end

    private_class_method :historical_reply_count,
                         :historical_reply_stats,
                         :historical_replies
  end
end
