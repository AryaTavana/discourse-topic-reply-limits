import { module, test } from "qunit";
import { incrementReplyLimitState } from "discourse/plugins/discourse-topic-reply-limits/discourse/initializers/reply-limit-client-state";

module("Unit | Initializer | reply-limit-client-state", function () {
  test("returns an absent state unchanged", function (assert) {
    assert.strictEqual(
      incrementReplyLimitState(undefined),
      undefined,
      "does not synthesize reply-limit state"
    );
  });

  test("updates counts and publishes threshold warnings", function (assert) {
    const state = {
      reached: false,
      reply_count: 3,
      assignments: [
        {
          rule_id: 1,
          reply_limit: 5,
          warning_at: 4,
          reply_count: 3,
          remaining: 2,
          reached: false,
          warning: false,
        },
      ],
      warnings: [],
    };

    const nextState = incrementReplyLimitState(state);

    assert.deepEqual(
      nextState,
      {
        reached: false,
        reply_count: 4,
        assignments: [
          {
            rule_id: 1,
            reply_limit: 5,
            warning_at: 4,
            reply_count: 4,
            remaining: 1,
            reached: false,
            warning: true,
          },
        ],
        warnings: [
          {
            rule_id: 1,
            reply_limit: 5,
            warning_at: 4,
            reply_count: 4,
            remaining: 1,
            reached: false,
            warning: true,
          },
        ],
      },
      "increments the shared count and exposes the warning assignment"
    );
    assert.strictEqual(state.reply_count, 3, "does not mutate server state");
  });

  test("marks the topic reached at any assignment limit", function (assert) {
    const state = {
      reached: false,
      reply_count: 4,
      assignments: [
        {
          rule_id: 1,
          reply_limit: 5,
          warning_at: 4,
          reply_count: 4,
          remaining: 1,
          reached: false,
          warning: true,
        },
        {
          rule_id: 2,
          reply_limit: 20,
          warning_at: 16,
          reply_count: 4,
          remaining: 16,
          reached: false,
          warning: false,
        },
      ],
      warnings: [],
    };

    const nextState = incrementReplyLimitState(state);

    assert.true(nextState.reached, "the topic is reached when one assignment is reached");
    assert.deepEqual(nextState.warnings, [], "reached assignments are not warnings");
    assert.deepEqual(
      nextState.assignments.map(({ remaining, reached }) => ({
        remaining,
        reached,
      })),
      [
        { remaining: 0, reached: true },
        { remaining: 15, reached: false },
      ],
      "each group assignment retains its independent limit"
    );
  });
});
