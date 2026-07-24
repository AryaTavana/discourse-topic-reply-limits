import { on } from "@ember/modifier";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader
    @titleLabel={{i18n "discourse_topic_reply_limits.admin.usage.title"}}
    @descriptionLabel={{i18n
      "discourse_topic_reply_limits.admin.usage.description"
    }}
  />

  <div class="admin-config-page__main-area topic-reply-limit-usage">
    <div class="topic-reply-limit-usage__period">
      <span class="topic-reply-limit-usage__period-label">
        {{i18n "discourse_topic_reply_limits.admin.usage.current_period"}}
      </span>
      <strong>
        {{dFormatDate
          @controller.report.meta.period_start
          format="medium"
          leaveAgo="true"
        }}
        –
        {{dFormatDate
          @controller.report.meta.next_credit_at
          format="medium"
          leaveAgo="true"
        }}
      </strong>
    </div>

    <form
      class="topic-reply-limit-usage__filter"
      {{on "submit" @controller.search}}
    >
      <label for="topic-reply-limit-usage-filter">
        {{i18n "discourse_topic_reply_limits.admin.usage.search"}}
      </label>
      <div class="topic-reply-limit-usage__filter-controls">
        <input
          id="topic-reply-limit-usage-filter"
          type="search"
          value={{@controller.query}}
          placeholder={{i18n
            "discourse_topic_reply_limits.admin.usage.search_placeholder"
          }}
          disabled={{@controller.loading}}
          {{on "input" @controller.updateQuery}}
        />
        <DButton
          @action={{@controller.search}}
          @icon="magnifying-glass"
          @label="discourse_topic_reply_limits.admin.usage.search_action"
          @isLoading={{@controller.loading}}
          class="btn-primary"
        />
        {{#if @controller.hasQuery}}
          <DButton
            @action={{@controller.clearSearch}}
            @label="discourse_topic_reply_limits.admin.usage.clear"
            @disabled={{@controller.loading}}
            class="btn-default"
          />
        {{/if}}
      </div>
    </form>

    <DConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.report.usage_records.length}}
        <p class="topic-reply-limit-usage__range" aria-live="polite">
          {{i18n
            "discourse_topic_reply_limits.admin.usage.showing"
            start=@controller.report.meta.start_index
            end=@controller.report.meta.end_index
            total=@controller.report.meta.total_count
          }}
        </p>

        <div class="topic-reply-limit-usage__table-wrapper">
          <table class="d-table topic-reply-limit-usage__table">
            <caption class="sr-only">
              {{i18n
                "discourse_topic_reply_limits.admin.usage.table_caption"
              }}
            </caption>
            <thead class="d-table__header">
              <tr class="d-table__row">
                <th class="d-table__header-cell">
                  {{i18n "discourse_topic_reply_limits.admin.usage.user"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_topic_reply_limits.admin.usage.topic"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_topic_reply_limits.admin.usage.group"}}
                </th>
                <th class="d-table__header-cell --numeric">
                  {{i18n "discourse_topic_reply_limits.admin.usage.monthly"}}
                </th>
                <th class="d-table__header-cell --numeric">
                  {{i18n "discourse_topic_reply_limits.admin.usage.carried"}}
                </th>
                <th class="d-table__header-cell --numeric">
                  {{i18n "discourse_topic_reply_limits.admin.usage.total"}}
                </th>
                <th class="d-table__header-cell --numeric">
                  {{i18n "discourse_topic_reply_limits.admin.usage.used"}}
                </th>
                <th class="d-table__header-cell --numeric">
                  {{i18n "discourse_topic_reply_limits.admin.usage.remaining"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_topic_reply_limits.admin.usage.status"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n
                    "discourse_topic_reply_limits.admin.usage.last_reply"
                  }}
                </th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each @controller.report.usage_records as |record|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">
                    <a
                      class="topic-reply-limit-usage__user"
                      href={{record.user.url}}
                    >
                      {{dBoundAvatarTemplate
                        record.user.avatar_template
                        "tiny"
                      }}
                      <span>
                        <strong>{{record.user.username}}</strong>
                        {{#if record.user.name}}
                          <small>{{record.user.name}}</small>
                        {{/if}}
                      </span>
                    </a>
                  </td>
                  <td class="d-table__cell">
                    <a href={{record.topic.url}}>
                      {{record.topic.title}}
                    </a>
                  </td>
                  <td class="d-table__cell">{{record.group.name}}</td>
                  <td class="d-table__cell --numeric">
                    {{record.monthly_allowance}}
                  </td>
                  <td class="d-table__cell --numeric">
                    {{record.carried_in}}
                  </td>
                  <td class="d-table__cell --numeric">
                    {{record.total_allowance}}
                  </td>
                  <td class="d-table__cell --numeric">
                    <strong>{{record.reply_count}}</strong>
                  </td>
                  <td class="d-table__cell --numeric">
                    <strong>{{record.remaining}}</strong>
                  </td>
                  <td class="d-table__cell">
                    {{#if record.reached}}
                      <span
                        class="topic-reply-limit-usage__status --reached"
                      >
                        {{i18n
                          "discourse_topic_reply_limits.admin.usage.reached"
                        }}
                      </span>
                    {{else}}
                      <span
                        class="topic-reply-limit-usage__status --available"
                      >
                        {{i18n
                          "discourse_topic_reply_limits.admin.usage.available"
                        }}
                      </span>
                    {{/if}}
                  </td>
                  <td class="d-table__cell">
                    {{#if record.last_reply_at}}
                      {{dFormatDate record.last_reply_at format="medium"}}
                    {{else}}
                      <span aria-label={{i18n
                        "discourse_topic_reply_limits.admin.usage.never"
                      }}>—</span>
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>

        <nav
          class="topic-reply-limit-usage__pagination"
          aria-label={{i18n
            "discourse_topic_reply_limits.admin.usage.pagination"
          }}
        >
          <DButton
            @action={{@controller.previousPage}}
            @icon="chevron-left"
            @label="discourse_topic_reply_limits.admin.usage.previous"
            @disabled={{@controller.previousDisabled}}
            class="btn-default"
          />
          <span>
            {{i18n
              "discourse_topic_reply_limits.admin.usage.page"
              page=@controller.report.meta.page
            }}
          </span>
          <DButton
            @action={{@controller.nextPage}}
            @icon="chevron-right"
            @label="discourse_topic_reply_limits.admin.usage.next"
            @disabled={{@controller.nextDisabled}}
            class="btn-default"
          />
        </nav>
      {{else}}
        <AdminConfigAreaEmptyList
          @emptyLabel={{if
            @controller.hasQuery
            "discourse_topic_reply_limits.admin.usage.no_results"
            "discourse_topic_reply_limits.admin.usage.empty"
          }}
        />
      {{/if}}
    </DConditionalLoadingSpinner>
  </div>
</template>
