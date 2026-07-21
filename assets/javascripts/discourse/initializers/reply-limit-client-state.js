import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

const MAX_REFRESH_DELAY = 6 * 60 * 60 * 1000;

export function incrementReplyLimitState(state) {
  if (!state) {
    return state;
  }

  const assignments = state.assignments.map((assignment) => {
    const replyCount = assignment.reply_count + 1;
    const remaining = Math.max(assignment.total_allowance - replyCount, 0);
    const reached = remaining === 0;

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
    reply_count: Math.max(
      ...assignments.map((assignment) => assignment.reply_count)
    ),
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
      let refreshTimer;

      const scheduleMonthlyRefresh = (topic) => {
        clearTimeout(refreshTimer);
        const nextCreditAt = topic?.reply_limit?.next_credit_at;
        if (!nextCreditAt) {
          return;
        }

        const remainingDelay = new Date(nextCreditAt).getTime() - Date.now();
        if (remainingDelay > MAX_REFRESH_DELAY) {
          refreshTimer = setTimeout(
            () => scheduleMonthlyRefresh(topic),
            MAX_REFRESH_DELAY
          );
          return;
        }

        refreshTimer = setTimeout(async () => {
          if (currentTopic !== topic) {
            return;
          }

          try {
            const result = await ajax(
              `/topic-reply-limits/topics/${topic.id}/status.json`
            );
            if (currentTopic !== topic) {
              return;
            }

            topic.set("reply_limit", result.reply_limit);
            topic.set("details.can_create_post", result.can_create_post);
            scheduleMonthlyRefresh(topic);
          } catch {
            refreshTimer = setTimeout(
              () => scheduleMonthlyRefresh(topic),
              60 * 1000
            );
          }
        }, Math.max(remainingDelay + 1000, 1000));
      };

      api.onAppEvent("page:topic-loaded", (topic) => {
        currentTopic = topic;
        scheduleMonthlyRefresh(topic);
      });

      api.onPageChange((url) => {
        if (
          currentTopic &&
          !new RegExp(`/t/(?:[^/]+/)?${currentTopic.id}(?:/|$)`).test(url)
        ) {
          currentTopic = undefined;
          clearTimeout(refreshTimer);
        }
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
        scheduleMonthlyRefresh(currentTopic);
      });
    });
  },
};
