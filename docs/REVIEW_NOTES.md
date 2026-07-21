# Senior review record for 1.1

Three improvement passes were performed against the current Discourse checkout.

## Pass 1 — accounting and concurrency

Reviewed rollover arithmetic, calendar boundaries, first-use backfill, deletion,
rule recreation, multiple groups, subscription gaps, and concurrent replies.

Improvements made:

- replaced the lifetime counter with immutable rule snapshots, membership
  intervals, and monthly group/topic usage rows;
- used half-open membership boundaries so removal exactly at a UTC month boundary
  does not earn that month;
- reset balances when subscription-group membership ends and scoped historical
  reply reconciliation to the new continuous membership;
- retained the user/topic advisory lock across all matching group checks and
  increments, plus a separate membership-transition lock;
- ordered expiration against affected user/topic locks so concurrent posting
  cannot recreate a stale balance after subscription removal;
- reconciled stored usage upward from deleted-inclusive post history.

## Pass 2 — performance and UX

Reviewed lazy accrual query shape, long-lived rules, open-page rollover, warning
clarity, dark/light theme contrast, and mobile layout.

Improvements made:

- batched membership intervals and historical post aggregates instead of issuing
  repeated queries for each missed month;
- stored monthly rule values so later edits cannot produce inconsistent lazy
  backfills;
- added the new allowance, carried amount, remaining amount, rollover policy,
  and localized next-credit date to user notices;
- added a bounded timer and guardian-checked status refresh so an open topic
  re-enables correctly after the calendar boundary;
- clarified all admin labels as monthly allowances and explained UTC/carryover.

## Pass 3 — security, migration, and compatibility

Reviewed privileged routes, arbitrary-user exposure, SQL inputs, overflow,
orphan cleanup, migration rollback, SSO/API membership paths, Ember imports, and
production asset compilation.

Improvements made:

- kept admin authorization at route/controller/service layers and current-user
  guardian authorization on status refresh;
- used bigint allowance/carry/usage columns, unique indexes, partial active-
  membership uniqueness, and database check constraints;
- covered both direct `GroupUser` callbacks and bulk GroupManager events
  idempotently;
- preserved legacy lifetime rows instead of destructively converting an
  ambiguous total into a month;
- retained parameter binding for all dynamic SQL and exposed no group/rule/user
  IDs in user state;
- verified ESLint, Stylelint, Prettier, the full frontend production bundle, and
  production asset precompilation before release.
