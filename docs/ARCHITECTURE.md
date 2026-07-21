# Architecture

## Ownership boundaries

Discourse owns topics, posts, groups, and reply enforcement. External systems
may manage group membership or administer rule sets through authenticated
Discourse APIs, but they do not write plugin tables directly.

The browser is advisory. The serialized topic state disables reply controls and
updates warning text immediately after a successful reply, while the model
callback remains authoritative for every post-creation path.

## Rule resolution

A rule row represents exactly one topic/group assignment. Matching uses
Discourse's `User#in_any_groups?` semantics, including supported automatic
groups. Staff users, private-message topics, and topics without matching rules
short-circuit before any usage query.

When multiple groups match, each rule evaluates the same lifetime topic usage
independently. Reaching any matching assignment rejects the next reply. No tier
selection or limit aggregation is performed.

## Counter lifecycle

Usage is keyed by `(user_id, topic_id)`, not by a rule. This is important:

- changing groups does not erase history;
- increasing or decreasing a limit immediately evaluates existing usage;
- deleting and recreating a rule does not restore quota;
- editing or deleting posts never mutates usage.

The first counted reply after installation or rule creation initializes usage
from all regular posts by that user in the topic via `Post.with_deleted`. The
new, unsaved reply is then incremented exactly once.

## Transaction and concurrency model

The post `before_create` callback executes inside the Active Record reply
transaction. Before reading or creating usage, it obtains a transaction-scoped
PostgreSQL advisory lock derived from the user/topic pair. It then locks the
usage row, checks all matching assignments, increments usage, and allows the post
insert to continue.

The advisory lock remains held until the outer reply transaction commits or
rolls back. This covers the otherwise unsafe first-use case where no row exists
to lock, and it works across threads and multiple Discourse application
processes. A later post failure rolls back the usage increment with the post.

Database uniqueness and check constraints are a final invariant layer.

## Warning calculation

The warning starts at:

```text
ceil(reply_limit * warning_percentage / 100)
```

For a limit of 20 and threshold of 80, the warning begins at reply 16 with four
remaining. The reached message replaces warnings once usage equals the limit.

## Security

- Admin rule routes have an `AdminConstraint`, an admin controller, and service
  policy checks.
- Strong parameters and service contracts constrain nested assignments.
- Topics must exist and use the regular archetype; all selected groups must
  exist; group IDs must be unique within a rule set.
- The user status endpoint requires login and `Guardian#ensure_can_see!`.
- User-facing state omits rule IDs, group IDs, and group names; it exposes only
  the counters and thresholds needed to render the warning.
- Staff bypass is enforced on the server, not inferred from client state.
- No endpoint accepts a user ID for reading or changing usage.
- Normal Discourse CSRF and API-key protections apply.

## Audit and cleanup

Atomic rule replacement and deletion are service transactions. Each change
writes a custom `UserHistory` staff action containing the topic and assignment
summary. Permanent destruction callbacks remove dependent plugin rows. Soft
deletion is intentionally retained.

## Future extension points

Useful additions that fit this design without weakening v1 semantics:

1. Entitlement-period counters using a Django-issued immutable period key.
2. Admin usage analytics and CSV export from read-only reporting endpoints.
3. Explicit, expiring per-user overrides with separate audit records.
4. A user dashboard backed by guardian-scoped aggregate status endpoints.
5. Discourse notifications at threshold/limit, with idempotency markers.

These are not mixed into the core rule path until their lifecycle and privacy
requirements are explicit.
