# NEoWaveChart Django integration review

No Django source was modified.

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

An hourly Celery reconciliation uses the Discourse API to add and remove all
managed groups after updating expiration state. Users without an extra forum
entitlement receive `base`.

## Production decision

Use UTC calendar months and the existing group boundary. No new Django endpoint
is required.

- Django remains authoritative for whether the subscriber is eligible and which
  tier group applies.
- Discourse observes group intervals, grants only eligible calendar months, and
  remains authoritative for committed reply transactions and carryover.
- Removing a group freezes its earned balance and stops monthly credits.
- Re-adding it restores the balance and credits the current calendar month once.
- A tier change closes one group ledger and opens another; balances are not
  combined because each configured group has its own independent rule.

This avoids sending consumption state to Django, avoids a second shared secret,
and keeps enforcement atomic with post creation. It also avoids awarding months
that elapsed while an expired subscriber was absent from the group.

## Why this is not a subscription-renewal reset

The requested policy says "each month" and "next month", so a UTC calendar month
is explicit and deterministic. The current Django data does not provide a stable
cross-system renewal-period identifier. Inferring one from an end date, a brief
group-sync failure, or overlapping purchases could duplicate or erase credit.

If the product later changes to billing-anniversary allowances, add an immutable
Django entitlement-period UUID and deliver it to a narrow authenticated,
idempotent plugin endpoint. Preserve old period ledgers, record Django event IDs,
and explicitly define upgrade/downgrade behavior. Do not overload group sync with
an inferred reset.

## API use

Django may manage topic rule sets through the existing administrator JSON API
using a dedicated Discourse API key with only the plugin's `read_rules` and/or
`manage_rules` scopes. Rule sets do not need to be resent on every subscription
change because the existing group synchronization changes eligibility.

Operational recommendations:

- require HTTPS and keep SSO/API secrets outside source control;
- alert on missing managed groups and partial synchronization failures;
- retain hourly reconciliation even though login-time SSO also updates groups;
- batch large membership reconciliations;
- align Django's exact expiration boundary in one shared entitlement predicate.
