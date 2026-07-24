import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowTopicReplyLimitsUsageRoute extends DiscourseRoute {
  async model() {
    return await ajax(
      "/admin/plugins/discourse-topic-reply-limits/usage.json"
    );
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.initializeReport(model);
  }
}
