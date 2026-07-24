import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Topic reply limits", function (needs) {
  needs.user();
  needs.settings({ topic_reply_limits_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/discourse-topic-reply-limits.json", () => {
      return helper.response({
        id: "discourse-topic-reply-limits",
        name: "discourse-topic-reply-limits",
        enabled: true,
        has_settings: true,
        humanized_name: "Topic reply limits",
        is_discourse_owned: false,
        admin_route: {
          label: "discourse_topic_reply_limits.admin.title",
          location: "discourse-topic-reply-limits",
          use_new_show_route: true,
        },
      });
    });

    server.get(
      "/admin/plugins/discourse-topic-reply-limits/rule-sets.json",
      () => helper.response({ rule_sets: [] })
    );

    server.get(
      "/admin/plugins/discourse-topic-reply-limits/usage.json",
      (request) => {
        const query = request.queryParams.q || "";
        const usageRecords =
          query === "missing"
            ? []
            : [
                {
                  id: "11:22:33",
                  user: {
                    id: 11,
                    username: "forum_master_user",
                    name: "Forum Master User",
                    avatar_template: "/images/avatar.png",
                    url: "/u/forum_master_user",
                  },
                  topic: {
                    id: 22,
                    title: "Gold Analysis Discussion",
                    url: "/t/gold-analysis-discussion/22",
                  },
                  group: { id: 33, name: "forum_master" },
                  monthly_allowance: 5,
                  carried_in: 2,
                  total_allowance: 7,
                  reply_count: 3,
                  remaining: 4,
                  reached: false,
                  last_reply_at: "2026-07-24T10:00:00.000Z",
                },
              ];

        return helper.response({
          usage_records: usageRecords,
          meta: {
            page: 1,
            per_page: 50,
            total_count: usageRecords.length,
            start_index: usageRecords.length,
            end_index: usageRecords.length,
            has_previous: false,
            has_more: false,
            query,
            period_start: "2026-07-01",
            next_credit_at: "2026-08-01T00:00:00.000Z",
          },
        });
      }
    );
  });

  test("directly loads the reply-limit rules route", async function (assert) {
    await visit(
      "/admin/plugins/discourse-topic-reply-limits/reply-limits"
    );

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-topic-reply-limits/reply-limits",
      "the nested plugin route survives a direct load"
    );
    assert
      .dom(".d-page-subheader")
      .includesText(
        i18n("discourse_topic_reply_limits.admin.rules.title"),
        "the reply-limit rules page renders"
      );
    assert
      .dom(".topic-reply-limit-rules")
      .exists("the reply-limit rule list renders");
  });

  test("renders the create rule form inside the admin card", async function (assert) {
    await visit(
      "/admin/plugins/discourse-topic-reply-limits/reply-limits/new"
    );

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-topic-reply-limits/reply-limits/new"
    );
    assert
      .dom(".admin-config-area-card__content .topic-reply-limit-form")
      .exists("the form is rendered in the card's named content block");
    assert
      .dom(".topic-reply-limit-form .form-kit__section")
      .exists({ count: 3 }, "the topic, group limits, and actions render");
  });

  test("shows active user balances on the usage route", async function (assert) {
    await visit(
      "/admin/plugins/discourse-topic-reply-limits/reply-limits/usage"
    );

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-topic-reply-limits/reply-limits/usage"
    );
    assert
      .dom(".topic-reply-limit-usage__table")
      .exists("the usage table renders");
    assert
      .dom(".topic-reply-limit-usage__table tbody tr")
      .exists({ count: 1 });
    assert
      .dom(".topic-reply-limit-usage__table")
      .includesText("forum_master_user")
      .includesText("Gold Analysis Discussion")
      .includesText("3")
      .includesText("4");
  });

  test("searches the usage report and shows its empty state", async function (assert) {
    await visit(
      "/admin/plugins/discourse-topic-reply-limits/reply-limits/usage"
    );

    await fillIn("#topic-reply-limit-usage-filter", "missing");
    await click(".topic-reply-limit-usage__filter .btn-primary");

    assert.dom(".topic-reply-limit-usage__table").doesNotExist();
    assert
      .dom(".admin-config-area-empty-list")
      .includesText(
        i18n("discourse_topic_reply_limits.admin.usage.no_results")
      );
  });
});
