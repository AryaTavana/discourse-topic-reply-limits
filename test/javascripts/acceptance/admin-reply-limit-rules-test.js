import { currentURL, visit } from "@ember/test-helpers";
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
});
