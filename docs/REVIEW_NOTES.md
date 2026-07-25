# Senior review record

## 2.0 subscription-anniversary review

Three additional production review passes were completed for 2.0.

### Pass 1 — entitlement architecture and accounting

- Replaced UTC calendar boundaries with exact subscription-anniversary cycles
  derived from Django's immutable subscription ID and purchase timestamp.
- Used original-anchor calendar arithmetic to prevent January 31 → February 28
  from drifting to March 28.
- Defined the active subscription as `[starts_at, ends_at)`, so an expiration
  exactly at the next anniversary cannot grant another allowance.
- Kept carryover only within one entitlement ID and made a new purchase start
  with a fresh ledger.
- Preserved all former lifetime/calendar tables for rollback and audit.

### Pass 2 — concurrency, security, and integration

- Added a narrow admin-only, granular API-key scope with validated batches,
  idempotent upsert/revocation, unknown-user reporting, and revocation
  tombstones.
- Serialized entitlement transitions with reply accounting locks and ordered
  multi-row locks to avoid cross-request deadlocks.
- Added immediate post-commit Django synchronization plus five-minute full
  reconciliation, including subscription transfers and deletions.
- Kept reply consumption exclusively in Discourse so post creation and counter
  increments remain one transaction.

### Pass 3 — UX, performance, and compatibility

- Added local exact next-credit dates, renewal/expiration explanations, and
  automatic open-topic refresh at either the next credit or subscription end.
- Added exact cycle bounds to the paginated admin usage report and replaced a
  fragile selected-column alias with an explicit rule/user row carrier.
- Batched Django entitlement delivery and SSO-record lookup.
- Verified the additive migration in both directions, Ruby/JavaScript lint,
  67 RSpec examples, 12 QUnit tests, and the full 152-test Django suite.

## 1.1 monthly-ledger review

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
