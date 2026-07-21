import { array, fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader
    @titleLabel={{i18n "discourse_topic_reply_limits.admin.rules.title"}}
    @descriptionLabel={{i18n
      "discourse_topic_reply_limits.admin.rules.description"
    }}
  >
    <:actions as |actions|>
      <actions.Primary
        @route="adminPlugins.show.topic-reply-limits.new"
        @icon="plus"
        @label="discourse_topic_reply_limits.admin.rules.add"
      />
    </:actions>
  </DPageSubheader>

  <div class="admin-config-page__main-area topic-reply-limit-rules">
    {{#if @model.length}}
      <AdminFilterControls
        @array={{@model}}
        @searchableProps={{array "topic_title"}}
        @inputPlaceholder={{i18n
          "discourse_topic_reply_limits.admin.rules.search"
        }}
        @noResultsMessage={{i18n
          "discourse_topic_reply_limits.admin.rules.no_results"
        }}
      >
        <:content as |filteredRuleSets|>
          <table class="d-table topic-reply-limit-rules__table">
            <thead class="d-table__header">
              <tr class="d-table__row">
                <th class="d-table__header-cell">{{i18n
                    "discourse_topic_reply_limits.admin.form.topic"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "discourse_topic_reply_limits.admin.rules.group_limits"
                  }}</th>
                <th class="d-table__header-cell"></th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each filteredRuleSets as |ruleSet|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">
                    <LinkTo
                      class="d-table__overview-link"
                      @route="adminPlugins.show.topic-reply-limits.edit"
                      @model={{ruleSet.topic_id}}
                    >
                      <span class="d-table__overview-name">{{ruleSet.topic_title}}</span>
                      <span class="topic-reply-limit-rules__topic-id">#{{ruleSet.topic_id}}</span>
                    </LinkTo>
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">{{i18n
                        "discourse_topic_reply_limits.admin.rules.group_limits"
                      }}</div>
                    <ul class="topic-reply-limit-rules__assignments">
                      {{#each ruleSet.assignments as |assignment|}}
                        <li class="topic-reply-limit-rules__assignment">
                          <span>{{assignment.group_name}}</span>
                          <span>{{i18n
                              "discourse_topic_reply_limits.admin.rules.limit_summary"
                              limit=assignment.reply_limit
                              percentage=assignment.warning_percentage
                            }}</span>
                        </li>
                      {{/each}}
                    </ul>
                  </td>
                  <td class="d-table__cell --controls">
                    <div class="d-table__cell-actions">
                      <DButton
                        @route="adminPlugins.show.topic-reply-limits.edit"
                        @routeModels={{array ruleSet.topic_id}}
                        @label="edit"
                        class="btn-default btn-small"
                      />
                      <DButton
                        @action={{fn @controller.destroyRuleSet ruleSet}}
                        @icon="trash-can"
                        @title="discourse_topic_reply_limits.admin.rules.delete"
                        class="btn-danger btn-small"
                      />
                    </div>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
      </AdminFilterControls>
    {{else}}
      <AdminConfigAreaEmptyList
        @emptyLabel="discourse_topic_reply_limits.admin.rules.empty"
        @ctaLabel="discourse_topic_reply_limits.admin.rules.add"
        @ctaRoute="adminPlugins.show.topic-reply-limits.new"
      />
    {{/if}}
  </div>
</template>
