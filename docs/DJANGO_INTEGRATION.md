# NEoWaveChart Django integration review

Django now sends an authoritative, idempotent reply-limit entitlement feed to
Discourse.

## Subscription model reviewed

`Marketplace.models.Subscription` stores an independent purchase row with a
start, optional end, active/expired/pending status, a forum-access snapshot, and
one tier snapshot (`general`, `advanced`, `master`, or `elite`). Product
durations use true calendar-month/calendar-year arithmetic.

A daily task expires subscriptions whose end has passed. New purchases create
new subscription rows; there is no shared immutable billing-cycle or renewal
chain sent to Discourse.

## Existing Discourse communication

Django's HMAC-verified DiscourseConnect flow sends the Django user ID, account
data, staff flags, and group additions/removals. Django resolves overlapping
active subscriptions to the highest forum tier and emits exactly one of:

- `forum_general`
- `forum_advanced`
- `forum_master`
- `forum_elite`

The five-minute Celery reconciliation uses the Discourse API to add and remove all
managed groups after updating expiration state. Users without an extra forum
entitlement receive `base`.

## Production decision

Django owns entitlement identity and time. For each user it selects the newest
active subscription within the highest active forum tier and sends:

- Django user ID (the DiscourseConnect external ID);
- immutable subscription row ID;
- selected Discourse group name;
- exact `Subscription.start_date`;
- exact `Subscription.end_date`, when present.

Discourse owns counters, carryover, and atomic post enforcement. Consumption is
never sent back to Django.

## Subscription reset boundary

The immutable subscription row ID is the ledger identity. Allowances are added
at `start_date + N calendar months`, preserving the original day/time where the
calendar permits. January 31 therefore produces February 28/29 and then March
31, rather than drifting permanently to the 28th.

The subscription interval is half-open: `[start_date, end_date)`. If `end_date`
equals the next anniversary, that expiring subscription does not receive
another allowance at that same instant. A new subscription row has a new ID and
starts with its configured base allowance and zero carryover.

Discourse computes missing cycles lazily under the same database lock used for
reply creation. There is deliberately no per-user reset cron job to miss,
duplicate, or run late.

## Delivery and reconciliation

`Forum.signals` queues an immediate single-user synchronization after a
subscription transaction commits. `Forum.tasks.sync_discourse_groups` remains
the five-minute full reconciliation and sends entitlements in batches of 200.
The plugin endpoint accepts up to 500.

The same Discourse API key already used by Django should be changed to a granular
key containing the required group-management scopes plus
`topic reply limits / sync entitlements`. The acting API user must be an
administrator.

## API use

Django may also manage topic rule sets through the existing administrator JSON API
using a dedicated Discourse API key with only the plugin's `read_rules` and/or
`manage_rules` scopes. Rule sets do not need to be resent on every subscription
change because the existing group synchronization changes eligibility.

Operational recommendations:

- require HTTPS and keep SSO/API secrets outside source control;
- alert on missing managed groups and partial synchronization failures;
- retain five-minute reconciliation even though subscription changes also
  enqueue an immediate single-user sync;
- batch large membership reconciliations;
- align Django's exact expiration boundary in one shared entitlement predicate.
