import { hash } from "@ember/helper";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DTooltips from "discourse/float-kit/components/d-tooltips";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ReplyLimitReachedIndicator from "discourse/plugins/discourse-topic-reply-limits/discourse/connectors/after-topic-footer-main-buttons/reply-limit-reached-indicator";

module(
  "Integration | Connector | reply-limit-footer-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows an accessible icon and tooltip at the limit", async function (assert) {
      await render(
        <template>
          <ReplyLimitReachedIndicator
            @outletArgs={{hash
              topic=(hash reply_limit=(hash reached=true))
            }}
          />
          <DTooltips />
        </template>
      );

      const tooltipText = i18n(
        "discourse_topic_reply_limits.footer_reached_tooltip"
      );
      assert
        .dom(".topic-reply-limits-footer-indicator")
        .exists()
        .hasAttribute("tabindex", "0")
        .hasAttribute("aria-label", tooltipText);
      assert
        .dom(".topic-reply-limits-footer-indicator .d-icon-circle-exclamation")
        .exists();

      await triggerEvent(
        ".topic-reply-limits-footer-indicator",
        "pointermove"
      );

      assert
        .dom(
          ".fk-d-tooltip__content[data-identifier='topic-reply-limit-reached']"
        )
        .hasAttribute("role", "tooltip")
        .hasText(tooltipText);
    });

    test("stays hidden while replies remain", async function (assert) {
      await render(
        <template>
          <ReplyLimitReachedIndicator
            @outletArgs={{hash
              topic=(hash reply_limit=(hash reached=false))
            }}
          />
          <DTooltips />
        </template>
      );

      assert.dom(".topic-reply-limits-footer-indicator").doesNotExist();
    });
  }
);
