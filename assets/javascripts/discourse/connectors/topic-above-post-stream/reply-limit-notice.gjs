import { trustHTML } from "@ember/template";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

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
        <span class="topic-reply-limits-notice__message">
          {{trustHTML
            (i18n
              "discourse_topic_reply_limits.next_credit"
              date=(dFormatDate
                @outletArgs.model.reply_limit.next_credit_at
                format="medium"
                noTitle=true
              )
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
          <span class="topic-reply-limits-notice__detail">
            {{trustHTML
              (i18n
                "discourse_topic_reply_limits.next_credit"
                date=(dFormatDate
                  @outletArgs.model.reply_limit.next_credit_at
                  format="medium"
                  noTitle=true
                )
              )
            }}
          </span>
        </div>
      </div>
    {{/each}}
  {{/if}}
</template>
