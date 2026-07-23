import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @outletArgs.topic.reply_limit.reached}}
    <DTooltip
      @identifier="topic-reply-limit-reached"
      @placement="top"
      @content={{i18n
        "discourse_topic_reply_limits.footer_reached_tooltip"
      }}
      @icon="circle-exclamation"
      aria-label={{i18n
        "discourse_topic_reply_limits.footer_reached_tooltip"
      }}
      tabindex="0"
      class="topic-reply-limits-footer-indicator"
    />
  {{/if}}
</template>
