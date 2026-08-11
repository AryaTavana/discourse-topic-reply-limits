# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class UsageReport
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100
    MAX_QUERY_LENGTH = 100
    Assignment = Data.define(:rule, :user_id)

    def initialize(page: nil, per_page: nil, query: nil)
      @at = Time.zone.now
      @page = positive_integer(page, default: 1)
      @per_page =
        positive_integer(per_page, default: DEFAULT_PER_PAGE).clamp(
          1,
          MAX_PER_PAGE
        )
      @query = query.to_s.strip[0, MAX_QUERY_LENGTH]
    end

    def call
      relation = filtered_assignments
      total_count = relation.count
      last_page = [(total_count.to_f / @per_page).ceil, 1].max
      @page = [@page, last_page].min
      assignment_ids =
        relation
          .order(
            Arel.sql(
              "LOWER(trll_users.username), LOWER(trll_topics.title), " \
                "LOWER(trll_groups.name), topic_reply_limit_rules.id"
            )
          )
          .offset((@page - 1) * @per_page)
          .limit(@per_page)
          .pluck("topic_reply_limit_rules.id", "trll_group_users.user_id")
      rules =
        Rule
          .includes(:topic, :group)
          .where(id: assignment_ids.map(&:first))
          .index_by(&:id)
      assignments =
        assignment_ids.filter_map do |rule_id, user_id|
          rule = rules[rule_id]
          Assignment.new(rule:, user_id:) if rule
        end

      rows = build_rows(assignments)
      {
        usage_records: rows,
        meta: {
          page: @page,
          per_page: @per_page,
          total_count:,
          start_index: total_count.zero? ? 0 : ((@page - 1) * @per_page) + 1,
          end_index: [@page * @per_page, total_count].min,
          has_previous: @page > 1,
          has_more: (@page * @per_page) < total_count,
          query: @query
        }
      }
    end

    private

    def filtered_assignments
      relation =
        Rule
          .joins(<<~SQL.squish)
              INNER JOIN group_users trll_group_users
                ON trll_group_users.group_id = topic_reply_limit_rules.group_id
              INNER JOIN users trll_users
                ON trll_users.id = trll_group_users.user_id
              INNER JOIN topics trll_topics
                ON trll_topics.id = topic_reply_limit_rules.topic_id
              INNER JOIN groups trll_groups
                ON trll_groups.id = topic_reply_limit_rules.group_id
              LEFT JOIN topic_reply_limit_entitlements trll_entitlements
                ON trll_entitlements.user_id = trll_group_users.user_id
            SQL
          .where("trll_topics.deleted_at IS NULL")
          .where(
            "trll_users.admin = FALSE AND trll_users.moderator = FALSE " \
              "AND trll_users.staged = FALSE"
          )
          .where(<<~SQL.squish, at: @at)
              trll_entitlements.id IS NULL OR (
                trll_entitlements.group_id = topic_reply_limit_rules.group_id
                AND trll_entitlements.revoked_at IS NULL
                AND trll_entitlements.starts_at <= :at
                AND (
                  trll_entitlements.ends_at IS NULL OR
                  trll_entitlements.ends_at > :at
                )
              )
            SQL

      return relation if @query.blank?

      term = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
      relation.where(<<~SQL.squish, term:)
          LOWER(trll_users.username) LIKE :term OR
          LOWER(COALESCE(trll_users.name, '')) LIKE :term OR
          LOWER(trll_topics.title) LIKE :term OR
          LOWER(trll_groups.name) LIKE :term
        SQL
    end

    def build_rows(assignments)
      users = User.where(id: assignments.map(&:user_id)).index_by(&:id)
      usages = materialize_usages(assignments, users)

      assignments.filter_map do |assignment|
        rule = assignment.rule
        user_id = assignment.user_id
        user = users[user_id]
        usage = usages[[user_id, rule.topic_id, rule.group_id]]
        next if user.blank? || usage.blank?

        {
          id: "#{user_id}:#{rule.topic_id}:#{rule.group_id}",
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
            avatar_template: user.avatar_template,
            url: user.relative_url
          },
          topic: {
            id: rule.topic.id,
            title: rule.topic.title,
            url: rule.topic.url
          },
          group: {
            id: rule.group.id,
            name: rule.group.name
          },
          period_start: usage.cycle_started_at,
          cycle_started_at: usage.cycle_started_at,
          cycle_ends_at: usage.cycle_ends_at,
          next_credit_at:
            usage.next_credit_at(
              Entitlement.current_for(user:, group: rule.group, at: @at)
            ),
          monthly_allowance: usage.monthly_allowance,
          carried_in: usage.carried_in,
          total_allowance: usage.total_allowance,
          reply_count: usage.reply_count,
          remaining: usage.remaining,
          reached: usage.remaining.zero?,
          last_reply_at: usage.last_reply_at
        }
      end
    end

    def materialize_usages(assignments, users)
      usages = {}

      assignments
        .group_by do |assignment|
          [assignment.user_id, assignment.rule.topic_id]
        end
        .each_value do |grouped_assignments|
          user = users[grouped_assignments.first.user_id]
          topic = grouped_assignments.first.rule.topic
          next if user.blank? || topic.blank?

          rules = grouped_assignments.map(&:rule)
          current =
            CycleUsage.current_for_rules!(user:, topic:, rules:, at: @at)
          grouped_assignments.each do |assignment|
            rule = assignment.rule
            usages[[user.id, rule.topic_id, rule.group_id]] = current[
              rule.group_id
            ]
          end
        end

      usages
    end

    def positive_integer(value, default:)
      integer = Integer(value, exception: false)
      integer&.positive? ? integer : default
    end
  end
end
