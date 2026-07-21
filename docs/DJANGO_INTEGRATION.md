# NEoWaveChart Django integration review

This decision record reflects the subscription code reviewed before implementing
the plugin. No Django source was modified.

## Current entitlement model

`Marketplace.models.Subscription` stores an independent row per purchase with:

- `start_date`, nullable `end_date`, and `active`/`expired`/`pending` status;
- a `forum_access` snapshot;
- one forum tier snapshot: `none`, `general`, `advanced`, `master`, or `elite`.

Duration-based purchases calculate calendar-month/calendar-year expiry and
create a new subscription row. There is no immutable renewal-chain or billing
period identifier shared with Discourse.

Active access requires active status, a started subscription, and no past end
date. A daily task updates subscription status, and the Discourse synchronization
task invokes that expiry update again before syncing.

## Current Discourse communication

The Django site uses DiscourseConnect SSO with HMAC verification and sends the
external Django user ID, account data, staff flags, and group additions/removals.

Forum tier precedence is resolved in Django. From all active forum subscriptions,
the highest tier is selected and exactly one of these groups is emitted:

- `forum_general`
- `forum_advanced`
- `forum_master`
- `forum_elite`

Superusers and staff map to Discourse admin/moderator status and their managed
groups. Users without an extra forum/forecast entitlement receive `base`.

In addition to login-time SSO synchronization, an hourly Celery task uses the
Discourse API to add and remove every managed group. It uses a cache lock,
bounded HTTP timeouts, and the configured `Api-Key`/`Api-Username` headers.

## Production decision for v1

Use lifetime reply counts per user/topic. Do not reset at subscription renewal
and do not copy subscription expiration timestamps into Discourse rules.

Reasons:

1. The requested base behavior defines a total created-reply counter.
2. Group membership already changes promptly through SSO and hourly API sync.
3. A purchase row is not yet a stable cross-system entitlement period. Inferring
   resets from `end_date`, group removal, or group re-addition would allow
   accidental resets during sync failures, upgrades, overlapping purchases, or
   tier changes.
4. Discourse is the only authoritative source for whether a reply transaction
   committed, was rejected, or was later deleted.

Django therefore remains authoritative for **who belongs to a tier**. Discourse
is authoritative for **topic rules and consumed replies**.

## Recommended future renewable-period design

If the product requirement later becomes "N replies per topic per paid period,"
make the period explicit rather than time-derived:

1. Add an immutable Django entitlement/period UUID. Link renewals and upgrades
   to a well-defined active period according to the business policy.
2. Send the current period key to Discourse through a narrow, authenticated,
   idempotent integration endpoint. Do not expose it as a browser-controlled SSO
   field without server verification.
3. Add `entitlement_key` (or a referenced entitlement table) to usage and change
   uniqueness to `(user_id, topic_id, entitlement_key)`.
4. Preserve old periods for audit/reporting. A new period selects a new counter;
   it does not zero or overwrite history.
5. Define upgrades explicitly: either preserve the same period and only change
   group/limit, or start a new period. The billing system must decide; the plugin
   must not guess.
6. Make delivery idempotent and signed, record the Django event ID, and reconcile
   periodically. Group sync and entitlement-period sync should remain separate
   operations.

This lets renewal resets be deterministic while retaining Discourse's
transactional reply accounting.

## API use today

Django may manage topic rule sets through the plugin's administrator endpoints,
using its existing server-to-server Discourse client. Use a dedicated Discourse
API key with the plugin's granular `topic_reply_limits` rule scopes and a
dedicated administrator acting account. Do not write PostgreSQL rows directly.

Rules do not need to be re-sent for every subscription change: Django's existing
group synchronization automatically changes which rule applies. The four tier
rules can be configured once per topic in Discourse Admin or idempotently updated
through the rule-set API.

Operational recommendations:

- require HTTPS and keep API/SSO secrets outside source control;
- alert on missing managed groups and partial synchronization failures;
- avoid sending all usernames in a single unbounded API request as the user base
  grows—batch or reconcile incrementally;
- keep the hourly reconciliation as a safety net even when SSO login updates a
  user immediately;
- align the exact expiration boundary (`<= now` versus `>= now`) in one shared
  Django entitlement predicate to avoid edge-time ambiguity.
