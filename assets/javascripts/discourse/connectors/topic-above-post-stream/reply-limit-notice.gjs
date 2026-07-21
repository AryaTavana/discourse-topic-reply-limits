import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @outletArgs.model.reply_limit.reached}}
    <div class="topic-reply-limits-notice --reached" role="status">
      {{dIcon "circle-exclamation"}}
      <span>{{i18n "discourse_topic_reply_limits.reached"}}</span>
    </div>
  {{else}}
    {{#each @outletArgs.model.reply_limit.warnings as |warning|}}
      <div class="topic-reply-limits-notice --warning" role="status">
        {{dIcon "triangle-exclamation"}}
        <span>{{i18n
            "discourse_topic_reply_limits.warning"
            percentage=warning.warning_percentage
            count=warning.remaining
          }}</span>
      </div>
    {{/each}}
  {{/if}}
</template>
