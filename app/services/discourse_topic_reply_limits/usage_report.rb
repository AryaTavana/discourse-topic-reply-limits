# frozen_string_literal: true

module DiscourseTopicReplyLimits
  class UsageReport
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100
    MAX_QUERY_LENGTH = 100

    def initialize(page: nil, per_page: nil, query: nil)
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
      assignments =
        relation
          .select(
            "topic_reply_limit_rules.*",
            "trll_group_users.user_id AS report_user_id"
          )
          .preload(:topic, :group)
          .order(
            Arel.sql(
              "LOWER(trll_users.username), LOWER(trll_topics.title), " \
                "LOWER(trll_groups.name), topic_reply_limit_rules.id"
            )
          )
          .offset((@page - 1) * @per_page)
          .limit(@per_page)
          .to_a

      rows = build_rows(assignments)
      period_start = Calendar.period_start

      {
        usage_records: rows,
        meta: {
          page: @page,
          per_page: @per_page,
          total_count:,
          start_index:
            total_count.zero? ? 0 : ((@page - 1) * @per_page) + 1,
          end_index: [@page * @per_page, total_count].min,
          has_previous: @page > 1,
          has_more: (@page * @per_page) < total_count,
          query: @query,
          period_start:,
          next_credit_at: Calendar.next_credit_at(period_start)
        }
      }
    end

    private

    def filtered_assignments
      relation =
        Rule
          .joins(
            <<~SQL.squish
              INNER JOIN group_users trll_group_users
                ON trll_group_users.group_id = topic_reply_limit_rules.group_id
              INNER JOIN users trll_users
                ON trll_users.id = trll_group_users.user_id
              INNER JOIN topics trll_topics
                ON trll_topics.id = topic_reply_limit_rules.topic_id
              INNER JOIN groups trll_groups
                ON trll_groups.id = topic_reply_limit_rules.group_id
            SQL
          )
          .where("trll_topics.deleted_at IS NULL")
          .where(
            "trll_users.admin = FALSE AND trll_users.moderator = FALSE " \
              "AND trll_users.staged = FALSE"
          )

      return relation if @query.blank?

      term =
        "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
      relation.where(
        <<~SQL.squish,
          LOWER(trll_users.username) LIKE :term OR
          LOWER(COALESCE(trll_users.name, '')) LIKE :term OR
          LOWER(trll_topics.title) LIKE :term OR
          LOWER(trll_groups.name) LIKE :term
        SQL
        term:
      )
    end

    def build_rows(assignments)
      users =
        User
          .where(id: assignments.map(&:report_user_id))
          .index_by(&:id)
      usages = materialize_usages(assignments, users)

      assignments.filter_map do |rule|
        user_id = rule.report_user_id.to_i
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
          period_start: usage.period_start,
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
        .group_by { |rule| [rule.report_user_id.to_i, rule.topic_id] }
        .each_value do |rules|
          user = users[rules.first.report_user_id.to_i]
          topic = rules.first.topic
          next if user.blank? || topic.blank?

          current =
            Usage.current_for_rules!(
              user:,
              topic:,
              rules:
            )
          rules.each do |rule|
            usages[[user.id, rule.topic_id, rule.group_id]] =
              current[rule.group_id]
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
