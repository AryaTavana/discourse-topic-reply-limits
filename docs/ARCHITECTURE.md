# Architecture

## Ownership boundaries

Django owns subscription status, identity, purchase/expiration timestamps, and
the user's selected forum tier. It synchronizes both group membership and a
narrow entitlement record to Discourse. Discourse owns topics, committed posts,
reply accounting, carryover, and enforcement.

The browser is advisory. Serialized state disables reply controls, updates after
a successful post, and refreshes at the next credit boundary. Server-side post
creation remains authoritative for web, mobile, API, email, and concurrent
requests.

## Subscription cycles and rollover

Each entitlement has an immutable external subscription ID and exact timestamp
anchor. Cycle `N` is bounded by `anchor + N calendar months` and
`anchor + (N + 1) calendar months`. Each boundary advances from the original
anchor rather than the prior boundary, preventing end-of-month drift.

The subscription interval is half-open: `[starts_at, ends_at)`. A cycle is not
granted when its start is at or after the subscription end.

```text
total_available = cycle_allowance + carried_in
remaining       = max(total_available - created_replies, 0)
next carried_in = remaining (same entitlement ID only)
```

Carryover is uncapped while the same subscription ID remains active. Revocation
makes its balance unavailable immediately. A later subscription ID starts with
the base allowance and zero carryover; historical rows remain available for
audit but are not consulted by the new ledger.

The warning starts at:

```text
ceil(total_available * warning_percentage / 100)
```

## Entitlement and rule history

`topic_reply_limit_rules` stores the administrator's current configuration.
`topic_reply_limit_rule_revisions` stores effective-dated active/inactive
revisions. A cycle snapshots the rule in force at its start. An edit therefore
applies to the next cycle without rewriting an already-granted allowance. A
brand-new rule may start in the current cycle.

`topic_reply_limit_entitlements` stores the authoritative Django subscription
selected for a user. Synchronization is idempotent by user and external
subscription ID. Revocation is retained as a tombstone, preventing a lagging
group removal from falling back to a fresh allowance.

For a safe pre-2.0 rollout, an active `MembershipPeriod` is used as a temporary
anchor only until Django sends the authoritative record. Removing and re-adding
the group creates a new fallback period ID and starts fresh.

If a user matches multiple configured groups, each group ledger is evaluated
and consumed independently. Reaching any matching assignment rejects the reply.
NEoWaveChart normally emits exactly one forum tier.

## Usage lifecycle and reconciliation

`topic_reply_limit_cycle_usages` is unique by
`(user_id, topic_id, group_id, entitlement_external_id, cycle_started_at)`.
Each row snapshots exact cycle bounds, base allowance, warning percentage,
carry-in, created replies, and last reply time.

Missing eligible cycles are materialized lazily. Regular replies created from
the start of the current entitlement are reconciled with `Post.with_deleted`;
the stored count only moves up. Soft deletion, permanent deletion, and editing
therefore never restore quota. Replies before the current subscription ID do
not consume its fresh allowance.

The 2.0 migration leaves all former lifetime and UTC-calendar tables untouched
for zero-downtime rollout, rollback, and audit safety. They are not consulted
for subscription-cycle enforcement.

## Transaction and concurrency model

The post `before_create` callback runs in the reply transaction. A PostgreSQL
transaction-scoped advisory lock derived from `(user_id, topic_id)` serializes
all applicable group ledgers, including first use when no row exists. Under
that lock, missing cycles are materialized, every matching balance is checked,
and all matching current rows are incremented.

The increment commits or rolls back with the post. Database unique indexes and
check constraints protect final invariants. At the exact subscription end
timestamp the entitlement is inactive even if the Django reconciliation or
group removal has not run yet.

There is deliberately no scheduled reset mutation. The first topic read, admin
report read, or reply after a boundary materializes the correct cycle under the
same lock. A delayed or unavailable background worker therefore cannot miss,
duplicate, or partially apply an anniversary credit.

## Admin usage reporting

The admin report begins with active user/topic/group assignments and excludes
staff, whose replies bypass the ledger. Search and pagination occur in
PostgreSQL before ledger work. Page size defaults to 50 and is capped at 100.

For each row on the requested page, the normal authoritative materialization
path fills missing cycles and reconciles created replies before returning exact
cycle dates, allowance, carryover, total available, current usage, remaining
balance, status, and last reply time.

## Security and lifecycle

- Rule routes require the admin constraint, admin controller, service policy,
  validated nested input, and normal CSRF/API authentication.
- Entitlement synchronization has its own granular API-key scope, maximum batch
  size of 500, strict timestamp validation, admin policy, and idempotent
  upsert/revocation behavior. It cannot mutate consumption.
- The status endpoint requires login and `Guardian#ensure_can_see!`; it only
  returns the current user's state and normal reply permission.
- User-facing state omits rule, group, and user identifiers.
- Staff bypass is decided on the server.
- SQL values are bound and fixed aggregate expressions are not user-controlled.
- Rule changes retain custom staff-action audit entries.
- Permanent group/user/topic destruction removes associated plugin records;
  soft-deleted topics retain them for restoration.

## Future extensions

Read-only user dashboards, analytics/export, expiring overrides, and idempotent
threshold notifications fit the cycle ledger without moving reply accounting to
Django.
