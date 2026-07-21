# Architecture

## Ownership boundaries

Django owns subscription status and selects a user's single active forum tier.
Its existing DiscourseConnect payload and hourly Discourse API reconciliation add
or remove the corresponding Discourse group. Discourse owns topics, committed
posts, monthly reply accounting, carryover, and enforcement.

The browser is advisory. Serialized state disables reply controls, updates after
a successful post, and refreshes at the next credit boundary. The server-side
post callback remains authoritative for web, mobile, API, email, and concurrent
requests.

## Calendar and rollover policy

Periods are UTC calendar months. A matching topic/group rule grants one base
allowance in every calendar month during which the user's group-membership
interval overlaps that month. A partial eligible month receives the full
allowance.

For each eligible period:

```text
total_available = monthly_allowance + carried_in
remaining       = max(total_available - created_replies, 0)
next carried_in = remaining
```

Carryover is intentionally uncapped while the same subscription-group membership
remains continuous. When that membership ends, all usage and carryover rows for
the user/group are deleted. A later membership starts with the current month's
base allowance and zero carryover, including when it begins in the same month.

The warning starts at:

```text
ceil(total_available * warning_percentage / 100)
```

This means the warning reflects everything the user can spend that month,
including rollover.

## Rule and membership history

`topic_reply_limit_rules` stores the administrator's current configuration.
`topic_reply_limit_rule_periods` snapshots the value granted for each month.
Before an administrator edits or deletes a rule, snapshots are filled through
the current month with the old value. The saved value therefore applies to the
next monthly credit and never retroactively changes an already granted balance.

`topic_reply_limit_membership_periods` records group intervals. Current members
are bootstrapped when a rule is created and during the 1.1 migration. Both
`GroupUser` callbacks and Discourse's bulk group events are observed, covering
the direct DiscourseConnect path and the GroupManager/API path. Duplicate events
are idempotent under a user/group advisory lock. Closing an interval deletes the
group's allowance ledger for that user, so a later interval creates a fresh
entitlement.

If a user matches multiple configured groups, each group ledger is evaluated and
consumed independently. Reaching any matching assignment rejects the reply. The
plugin does not select a highest or lowest tier. NEoWaveChart normally emits one
forum tier, so subscribers normally have one applicable ledger.

## Usage lifecycle and historical reconciliation

`topic_reply_limit_period_usages` is unique by
`(user_id, topic_id, group_id, period_start)`. Each row snapshots the base
allowance and warning percentage, records carry-in and created replies, and
stores the last reply time.

Missing eligible months are materialized lazily. Regular replies created from
the start of the current continuous membership are reconciled in batches with
`Post.with_deleted`; the stored value only moves up. Consequently, soft deletion,
permanent deletion, and editing can never restore quota. Replies from before the
current subscription—including an earlier subscription in the same month—do
not consume its fresh allowance.

The 1.1 migration leaves the old `topic_reply_limit_usages` table untouched for
zero-downtime rollout and rollback/audit safety. It is never consulted for
monthly enforcement. The first monthly materialization uses authoritative
current-month posts instead of trying to reinterpret a lifetime total.

## Transaction and concurrency model

The post `before_create` callback runs in the reply transaction. A PostgreSQL
transaction-scoped advisory lock derived from `(user_id, topic_id)` serializes
all applicable group ledgers, including first use when no row exists. Under that
lock, missing periods are materialized, every matching balance is checked, and
all matching current rows are incremented.

The increment commits or rolls back with the post. Database unique indexes and
check constraints protect the final invariants. A separate advisory lock
serializes membership transitions by `(user_id, group_id)`. Expiration first
acquires the affected user/topic locks in stable order, then the membership
lock, and finally removes the ledgers. A concurrent reply therefore either
commits before expiration and is erased with that subscription or observes the
closed membership and is rejected. Reply transactions also take a PostgreSQL
`FOR KEY SHARE` lock on the applicable `GroupUser` row; concurrent replies can
share it, while group removal cannot cross the entitlement check mid-transaction.

## Security and lifecycle

- Rule routes require the admin constraint, admin controller, service policy,
  validated nested input, and normal CSRF/API authentication.
- The status endpoint requires login and `Guardian#ensure_can_see!`; it can only
  return the current user's state and normal reply permission.
- User-facing state omits rule, group, and user identifiers.
- Staff bypass is decided on the server.
- SQL values are bound; fixed aggregate expressions are not user-controlled.
- Rule changes retain custom staff-action audit entries.
- Permanent group/user/topic destruction removes associated plugin records;
  soft-deleted topics retain them for restoration.

## Future extensions

Read-only user dashboards, analytics/export, expiring overrides, and idempotent
threshold notifications fit this ledger. Billing-anniversary periods require a
separate signed entitlement identifier from Django; they must not be inferred
from group removal/re-addition.
