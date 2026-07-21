# frozen_string_literal: true

class CreateTopicReplyLimitTables < ActiveRecord::Migration[8.0]
  def change
    create_table :topic_reply_limit_rules do |table|
      table.bigint :topic_id, null: false
      table.bigint :group_id, null: false
      table.integer :reply_limit, null: false
      table.integer :warning_percentage, null: false, default: 80
      table.timestamps null: false
    end

    add_index :topic_reply_limit_rules, %i[topic_id group_id], unique: true
    add_index :topic_reply_limit_rules, :group_id
    add_check_constraint :topic_reply_limit_rules,
                         "reply_limit > 0",
                         name: "trll_rules_limit_positive"
    add_check_constraint :topic_reply_limit_rules,
                         "warning_percentage BETWEEN 1 AND 99",
                         name: "trll_rules_warning_percentage"

    create_table :topic_reply_limit_usages do |table|
      table.bigint :user_id, null: false
      table.bigint :topic_id, null: false
      table.integer :reply_count, null: false, default: 0
      table.datetime :last_reply_at
      table.timestamps null: false
    end

    add_index :topic_reply_limit_usages, %i[user_id topic_id], unique: true
    add_index :topic_reply_limit_usages, :topic_id
    add_check_constraint :topic_reply_limit_usages,
                         "reply_count >= 0",
                         name: "trll_usages_reply_count_non_negative"
  end
end
