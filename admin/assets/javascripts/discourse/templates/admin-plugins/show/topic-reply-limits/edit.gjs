import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import { i18n } from "discourse-i18n";
import TopicReplyLimitRuleSetForm from "discourse/plugins/discourse-topic-reply-limits/admin/components/topic-reply-limit-rule-set-form";

export default <template>
  <BackButton
    @route="adminPlugins.show.topic-reply-limits"
    @label="discourse_topic_reply_limits.admin.form.back"
  />
  <AdminConfigAreaCard
    @translatedHeading={{i18n
      "discourse_topic_reply_limits.admin.form.edit_title"
    }}
  >
    <:content>
      <TopicReplyLimitRuleSetForm @model={{@model}} @editing={{true}} />
    </:content>
  </AdminConfigAreaCard>
</template>
