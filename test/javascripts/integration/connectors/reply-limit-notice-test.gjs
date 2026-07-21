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
                warnings=(array
                  (hash warning_percentage=80 remaining=4)
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
  });

  test("renders an assertive reached-limit alert", async function (assert) {
    await render(
      <template>
        <ReplyLimitNotice
          @outletArgs={{hash
            model=(hash reply_limit=(hash reached=true warnings=(array)))
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
      .dom(".topic-reply-limits-notice__message")
      .hasText(i18n("discourse_topic_reply_limits.reached"));
  });
});
