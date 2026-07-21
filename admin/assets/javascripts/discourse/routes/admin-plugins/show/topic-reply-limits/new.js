import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowTopicReplyLimitsNewRoute extends DiscourseRoute {
  model() {
    return {
      topic_id: null,
      assignments: [
        { group_id: null, reply_limit: 5, warning_percentage: 80 },
      ],
    };
  }
}
