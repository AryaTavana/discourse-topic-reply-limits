# frozen_string_literal: true

class AddMonthlyReplyAllowances < ActiveRecord::Migration[8.0]
  def up
    create_table :topic_reply_limit_rule_periods do |table|
      table.bigint :rule_id, null: false
      table.bigint :topic_id, null: false
      table.bigint :group_id, null: false
      table.date :period_start, null: false
      table.integer :reply_limit, null: false
      table.integer :warning_percentage, null: false
      table.timestamps null: false
    end

    add_index :topic_reply_limit_rule_periods,
              %i[topic_id group_id period_start],
              unique: true,
              name: "trll_rule_periods_unique"
    add_index :topic_reply_limit_rule_periods, :rule_id
    add_index :topic_reply_limit_rule_periods, :group_id
    add_check_constraint :topic_reply_limit_rule_periods,
                         "reply_limit > 0",
                         name: "trll_rule_periods_limit_positive"
    add_check_constraint :topic_reply_limit_rule_periods,
                         "warning_percentage BETWEEN 1 AND 99",
                         name: "trll_rule_periods_warning_percentage"

    create_table :topic_reply_limit_membership_periods do |table|
      table.bigint :user_id, null: false
      table.bigint :group_id, null: false
      table.datetime :starts_at, null: false
      table.datetime :ends_at
      table.timestamps null: false
    end

    add_index :topic_reply_limit_membership_periods,
              %i[user_id group_id],
              unique: true,
              where: "ends_at IS NULL",
              name: "trll_active_membership_unique"
    add_index :topic_reply_limit_membership_periods,
              %i[user_id group_id starts_at],
              name: "trll_membership_history"
    add_index :topic_reply_limit_membership_periods, :group_id
    add_check_constraint :topic_reply_limit_membership_periods,
                         "ends_at IS NULL OR ends_at >= starts_at",
                         name: "trll_membership_period_valid"

    create_table :topic_reply_limit_period_usages do |table|
      table.bigint :user_id, null: false
      table.bigint :topic_id, null: false
      table.bigint :group_id, null: false
      table.date :period_start, null: false
      table.bigint :monthly_allowance, null: false
      table.integer :warning_percentage, null: false
      table.bigint :carried_in, null: false, default: 0
      table.bigint :reply_count, null: false, default: 0
      table.datetime :last_reply_at
      table.timestamps null: false
    end

    add_index :topic_reply_limit_period_usages,
              %i[user_id topic_id group_id period_start],
              unique: true,
              name: "trll_usages_period_unique"
    add_index :topic_reply_limit_period_usages,
              %i[topic_id period_start],
              name: "trll_usages_topic_period"
    add_index :topic_reply_limit_period_usages,
              %i[group_id period_start],
              name: "trll_usages_group_period"
    add_check_constraint :topic_reply_limit_period_usages,
                         "monthly_allowance > 0",
                         name: "trll_usages_allowance_positive"
    add_check_constraint :topic_reply_limit_period_usages,
                         "warning_percentage BETWEEN 1 AND 99",
                         name: "trll_usages_warning_percentage"
    add_check_constraint :topic_reply_limit_period_usages,
                         "carried_in >= 0",
                         name: "trll_usages_carry_non_negative"
    add_check_constraint :topic_reply_limit_period_usages,
                         "reply_count >= 0",
                         name: "trll_period_usages_reply_count_non_negative"

    execute <<~SQL
      INSERT INTO topic_reply_limit_rule_periods
        (rule_id, topic_id, group_id, period_start, reply_limit,
         warning_percentage, created_at, updated_at)
      SELECT
        id, topic_id, group_id, DATE_TRUNC('month', CURRENT_TIMESTAMP)::date,
        reply_limit, warning_percentage, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM topic_reply_limit_rules
      ON CONFLICT (topic_id, group_id, period_start) DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO topic_reply_limit_membership_periods
        (user_id, group_id, starts_at, created_at, updated_at)
      SELECT
        gu.user_id, gu.group_id, gu.created_at, CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM group_users gu
      WHERE EXISTS (
        SELECT 1
        FROM topic_reply_limit_rules rules
        WHERE rules.group_id = gu.group_id
      )
      ON CONFLICT (user_id, group_id) WHERE ends_at IS NULL DO NOTHING
    SQL
  end

  def down
    drop_table :topic_reply_limit_period_usages
    drop_table :topic_reply_limit_membership_periods
    drop_table :topic_reply_limit_rule_periods
  end
end
