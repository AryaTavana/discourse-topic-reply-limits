import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowTopicReplyLimitsEditRoute extends DiscourseRoute {
  async model(params) {
    const response = await ajax(
      `/admin/plugins/discourse-topic-reply-limits/rule-sets/${params.topic_id}.json`
    );
    return response.rule_set;
  }
}
