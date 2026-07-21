import { array, hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ReplyLimitNotice from "discourse/plugins/discourse-topic-reply-limits/discourse/connectors/topic-above-post-stream/reply-limit-notice";

module("Integration | Connector | reply-limit-notice", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a visible warning with the remaining count", async function (assert) {
    await render(
      <template>
        <ReplyLimitNotice
          @outletArgs={{hash
            model=(hash
              reply_limit=(hash
                reached=false
                next_credit_at="2026-08-01T00:00:00.000Z"
                warnings=(array
                  (hash
                    warning_percentage=80
                    remaining=4
                    monthly_reply_limit=20
                    carried_in=3
                  )
                )
              )
            )
          }}
        />
      </template>
    );

    assert
      .dom(".topic-reply-limits-notice.--warning[role='status']")
      .exists();
    assert
      .dom(".topic-reply-limits-notice__title")
      .hasText(i18n("discourse_topic_reply_limits.warning_title"));
    assert
      .dom(".topic-reply-limits-notice__remaining")
      .hasText(
        i18n("discourse_topic_reply_limits.remaining", { count: 4 })
      );
    assert
      .dom(".topic-reply-limits-notice.--warning")
      .includesText("20")
      .includesText("3")
      .includesText(
        i18n(
          "discourse_topic_reply_limits.subscription_reset_explanation"
        )
      );
  });

  test("renders an assertive reached-limit alert", async function (assert) {
    await render(
      <template>
        <ReplyLimitNotice
          @outletArgs={{hash
            model=(hash
              reply_limit=(hash
                reached=true
                next_credit_at="2026-08-01T00:00:00.000Z"
                warnings=(array)
              )
            )
          }}
        />
      </template>
    );

    assert
      .dom(".topic-reply-limits-notice.--reached[role='alert']")
      .hasAttribute("aria-live", "assertive");
    assert
      .dom(".topic-reply-limits-notice__title")
      .hasText(i18n("discourse_topic_reply_limits.reached_title"));
    assert
      .dom(".topic-reply-limits-notice__message:first-of-type")
      .hasText(i18n("discourse_topic_reply_limits.reached"));
    assert
      .dom(".topic-reply-limits-notice.--reached")
      .includesText(
        i18n(
          "discourse_topic_reply_limits.subscription_reset_explanation"
        )
      );
  });
});
