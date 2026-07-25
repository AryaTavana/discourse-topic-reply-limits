# frozen_string_literal: true
class CreateSubscriptionAnchoredReplyAllowances < ActiveRecord::Migration[8.0]
  def up
    create_table :topic_reply_limit_entitlements do |t|
      t.bigint :user_id, null: false
      t.bigint :group_id
      t.string :external_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :topic_reply_limit_entitlements, :user_id, unique: true
    add_index :topic_reply_limit_entitlements, :external_id, unique: true
    add_index :topic_reply_limit_entitlements, %i[group_id starts_at]
    add_check_constraint(
      :topic_reply_limit_entitlements,
      "ends_at IS NULL OR ends_at > starts_at",
      name: "trll_entitlements_valid_interval"
    )
    add_check_constraint(
      :topic_reply_limit_entitlements,
      "(group_id IS NOT NULL OR revoked_at IS NOT NULL) AND " \
        "(revoked_at IS NULL OR revoked_at >= starts_at)",
      name: "trll_entitlements_valid_state"
    )

    create_table :topic_reply_limit_rule_revisions do |t|
      t.bigint :topic_id, null: false
      t.bigint :group_id, null: false
      t.datetime :effective_at, null: false
      t.integer :reply_limit
      t.integer :warning_percentage
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index(
      :topic_reply_limit_rule_revisions,
      %i[topic_id group_id effective_at],
      name: "idx_trll_rule_revisions_lookup"
    )
    add_check_constraint(
      :topic_reply_limit_rule_revisions,
      "(active AND reply_limit > 0 AND warning_percentage > 0 AND " \
        "warning_percentage < 100) OR " \
        "(NOT active AND reply_limit IS NULL AND warning_percentage IS NULL)",
      name: "trll_rule_revisions_valid_values"
    )

    create_table :topic_reply_limit_cycle_usages do |t|
      t.bigint :user_id, null: false
      t.bigint :topic_id, null: false
      t.bigint :group_id, null: false
      t.string :entitlement_external_id, null: false
      t.datetime :cycle_started_at, null: false
      t.datetime :cycle_ends_at, null: false
      t.integer :monthly_allowance, null: false
      t.integer :warning_percentage, null: false
      t.bigint :carried_in, null: false, default: 0
      t.bigint :reply_count, null: false, default: 0
      t.datetime :last_reply_at
      t.timestamps
    end

    add_index(
      :topic_reply_limit_cycle_usages,
      %i[user_id topic_id group_id entitlement_external_id cycle_started_at],
      unique: true,
      name: "idx_trll_cycle_usages_identity"
    )
    add_index(
      :topic_reply_limit_cycle_usages,
      %i[topic_id cycle_started_at],
      name: "idx_trll_cycle_usages_topic_cycle"
    )
    add_index(
      :topic_reply_limit_cycle_usages,
      %i[user_id group_id cycle_started_at],
      name: "idx_trll_cycle_usages_user_group_cycle"
    )
    add_check_constraint(
      :topic_reply_limit_cycle_usages,
      "cycle_ends_at > cycle_started_at",
      name: "trll_cycle_usages_valid_interval"
    )
    add_check_constraint(
      :topic_reply_limit_cycle_usages,
      "monthly_allowance > 0 AND warning_percentage > 0 AND " \
        "warning_percentage < 100 AND carried_in >= 0 AND reply_count >= 0",
      name: "trll_cycle_usages_valid_values"
    )
  end

  def down
    drop_table :topic_reply_limit_cycle_usages
    drop_table :topic_reply_limit_rule_revisions
    drop_table :topic_reply_limit_entitlements
  end
end
