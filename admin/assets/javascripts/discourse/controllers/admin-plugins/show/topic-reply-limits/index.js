import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowTopicReplyLimitsIndexController extends Controller {
  @service dialog;
  @service toasts;

  @action
  destroyRuleSet(ruleSet) {
    this.dialog.deleteConfirm({
      message: i18n(
        "discourse_topic_reply_limits.admin.rules.delete_confirm",
        { topic: ruleSet.topic_title }
      ),
      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/discourse-topic-reply-limits/rule-sets/${ruleSet.topic_id}.json`,
            { type: "DELETE" }
          );
          this.model = this.model.filter(
            (candidate) => candidate.topic_id !== ruleSet.topic_id
          );
          this.toasts.success({
            duration: "short",
            data: {
              message: i18n(
                "discourse_topic_reply_limits.admin.rules.delete_success"
              ),
            },
          });
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
