# frozen_string_literal: true

class AddCarryoverLimitsToTopicReplyLimitRules < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_reply_limit_rules, :carryover_limit, :integer
    add_check_constraint(
      :topic_reply_limit_rules,
      "carryover_limit IS NULL OR carryover_limit BETWEEN 0 AND 1000000",
      name: "trll_rules_carryover_limit"
    )

    add_column :topic_reply_limit_rule_revisions, :carryover_limit, :integer
    add_check_constraint(
      :topic_reply_limit_rule_revisions,
      "carryover_limit IS NULL OR " \
        "(active AND carryover_limit BETWEEN 0 AND 1000000)",
      name: "trll_rule_revisions_carryover_limit"
    )
  end
end
