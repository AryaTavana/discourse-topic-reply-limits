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
        </div>
      </div>
    {{/each}}
  {{/if}}
</template>
