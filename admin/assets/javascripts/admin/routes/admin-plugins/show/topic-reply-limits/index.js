import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowTopicReplyLimitsIndexRoute extends DiscourseRoute {
  async model() {
    const response = await ajax(
      "/admin/plugins/discourse-topic-reply-limits/rule-sets.json"
    );
    return response.rule_sets;
  }
}
