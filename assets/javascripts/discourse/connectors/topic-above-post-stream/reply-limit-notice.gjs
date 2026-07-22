import { helper } from "@ember/component/helper";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const formatUtcDateTime = helper(([value]) => {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const options = {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: "UTC",
  };
  const locale = I18n.currentLocale()?.replaceAll("_", "-");
  let formatted;

  try {
    formatted = new Intl.DateTimeFormat(locale || undefined, options).format(
      date
    );
  } catch {
    formatted = new Intl.DateTimeFormat(undefined, options).format(date);
  }

  return `${formatted} UTC`;
});

export default <template>
  {{#if @outletArgs.model.reply_limit.reached}}
    <div
      class="topic-reply-limits-notice --reached"
      role="alert"
      aria-live="assertive"
      aria-atomic="true"
    >
      <span class="topic-reply-limits-notice__icon" aria-hidden="true">
        {{dIcon "circle-exclamation"}}
      </span>
      <div class="topic-reply-limits-notice__content">
        <strong class="topic-reply-limits-notice__title">
          {{i18n "discourse_topic_reply_limits.reached_title"}}
        </strong>
        <span class="topic-reply-limits-notice__message">
          {{i18n "discourse_topic_reply_limits.reached"}}
        </span>
        <span
          class="topic-reply-limits-notice__message topic-reply-limits-notice__next-credit"
        >
          {{i18n
            "discourse_topic_reply_limits.next_credit"
            date=(formatUtcDateTime
              @outletArgs.model.reply_limit.next_credit_at
            )
          }}
        </span>
        <span class="topic-reply-limits-notice__detail">
          {{i18n "discourse_topic_reply_limits.rollover_explanation"}}
        </span>
        <span class="topic-reply-limits-notice__detail">
          {{i18n
            "discourse_topic_reply_limits.subscription_reset_explanation"
          }}
        </span>
      </div>
    </div>
  {{else}}
    {{#each @outletArgs.model.reply_limit.warnings as |warning|}}
      <div
        class="topic-reply-limits-notice --warning"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        <span class="topic-reply-limits-notice__icon" aria-hidden="true">
          {{dIcon "triangle-exclamation"}}
        </span>
        <div class="topic-reply-limits-notice__content">
          <strong class="topic-reply-limits-notice__title">
            {{i18n "discourse_topic_reply_limits.warning_title"}}
          </strong>
          <span class="topic-reply-limits-notice__message">
            {{i18n
              "discourse_topic_reply_limits.warning_usage"
              percentage=warning.warning_percentage
            }}
          </span>
          <strong class="topic-reply-limits-notice__remaining">
            {{i18n
              "discourse_topic_reply_limits.remaining"
              count=warning.remaining
            }}
          </strong>
          <span class="topic-reply-limits-notice__detail">
            {{i18n
              "discourse_topic_reply_limits.allowance_breakdown"
              monthly=warning.monthly_reply_limit
              carried=warning.carried_in
            }}
          </span>
          <span class="topic-reply-limits-notice__detail">
            {{i18n "discourse_topic_reply_limits.rollover_explanation"}}
          </span>
          <span class="topic-reply-limits-notice__detail">
            {{i18n
              "discourse_topic_reply_limits.subscription_reset_explanation"
            }}
          </span>
          <span
            class="topic-reply-limits-notice__detail topic-reply-limits-notice__next-credit"
          >
            {{i18n
              "discourse_topic_reply_limits.next_credit"
              date=(formatUtcDateTime
                @outletArgs.model.reply_limit.next_credit_at
              )
            }}
          </span>
        </div>
      </div>
    {{/each}}
  {{/if}}
</template>
