import { withPluginApi } from "discourse/lib/plugin-api";

export function incrementReplyLimitState(state) {
  if (!state) {
    return state;
  }

  const replyCount = state.reply_count + 1;
  const assignments = state.assignments.map((assignment) => {
    const remaining = Math.max(assignment.reply_limit - replyCount, 0);
    const reached = replyCount >= assignment.reply_limit;

    return {
      ...assignment,
      reply_count: replyCount,
      remaining,
      reached,
      warning: !reached && replyCount >= assignment.warning_at,
    };
  });

  return {
    ...state,
    reply_count: replyCount,
    reached: assignments.some((assignment) => assignment.reached),
    assignments,
    warnings: assignments.filter((assignment) => assignment.warning),
  };
}

export default {
  name: "topic-reply-limits-client-state",

  initialize() {
    withPluginApi((api) => {
      let currentTopic;

      api.onAppEvent("page:topic-loaded", (topic) => {
        currentTopic = topic;
      });

      api.onAppEvent("post:created", (post) => {
        if (
          !currentTopic?.reply_limit ||
          post.topic_id !== currentTopic.id ||
          post.post_number <= 1
        ) {
          return;
        }

        const nextState = incrementReplyLimitState(currentTopic.reply_limit);
        currentTopic.set("reply_limit", nextState);

        if (nextState.reached) {
          currentTopic.set("details.can_create_post", false);
        }
      });
    });
  },
};
