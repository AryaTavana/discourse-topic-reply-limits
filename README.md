# discourse-topic-reply-limits

`discourse-topic-reply-limits` adds authoritative, per-topic reply quotas for
Discourse groups. Administrators manage rules in a dedicated modern Discourse
Admin interface. It does not replace Discourse category security and it does not
grant access to topics.

## Features

- One or more group-specific limits for any regular topic.
- Topic and group search/select controls in Discourse Admin.
- Allowance cycles anchored to the exact subscription purchase timestamp, with
  a configurable unused-reply carryover cap per group assignment.
- Authoritative Django entitlement synchronization: subscription ID, tier,
  purchase time, and expiration are delivered through a narrow idempotent API.
- Configurable warning threshold per group (80% by default), calculated against
  the cycle's new allowance plus carryover.
- Server-side enforcement for web, mobile, API, and email-created replies.
- Immediate client-side warning updates and reply-composer disabling.
- Staff bypass for administrators and moderators.
- Per-cycle created-reply counters: deletion never restores quota and editing
  never consumes quota.
- Current-cycle backfill includes regular replies created during the current
  subscription before the rule became active, including soft-deleted replies.
- Transaction-scoped locking, database uniqueness, and check constraints.
- Staff action audit entries for rule changes.
- Searchable, paginated admin usage reporting with current used and remaining
  balances.
- Admin JSON rule/usage APIs and a guardian-protected current-user status API.

## Compatibility

The plugin targets the latest stable Discourse release and uses the current
Glimmer/FormKit admin architecture. The plugin metadata requires Discourse
3.5.0 or newer.

## Production installation

Add the plugin clone command to the `after_code` section of the Discourse
container's `containers/app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/AryaTavana/discourse-topic-reply-limits.git
```

Then rebuild the container from the Discourse Docker directory:

```shell
./launcher rebuild app
```

Discourse runs the plugin migration during the rebuild. Back up the database
before installing or upgrading any production plugin.

For a development checkout, clone this repository directly under
`discourse/plugins/`, then run the normal Discourse migrations:

```shell
cd /path/to/discourse/plugins
git clone https://github.com/AryaTavana/discourse-topic-reply-limits.git
cd ..
bundle exec rails db:migrate
```

## Configuration

1. In **Admin > Plugins**, enable `topic reply limits enabled` if it is not
   already enabled.
2. Open **Admin > Plugins > Topic reply limits > Reply limit rules**.
3. Select an existing regular topic.
4. Add one or more group assignments, each with its own reply allowance per
   subscription cycle, warning percentage, and optional carryover cap. Enter
   `0` to disable carryover or leave the cap blank for unlimited carryover.
5. Save the rule set.

Open **Admin > Plugins > Topic reply limits > User usage** to review each
active user's cycle dates, allowance, carryover, used replies, current remaining
balance, status, and last reply for every matching topic/group assignment.
Administrators and moderators are omitted because they bypass limits. Users
whose subscription group has been removed are omitted because expiration
removes their active allowance.

For example, one topic can have these independent assignments:

| Group | Allowance per subscription cycle | Carryover cap | Warning |
| --- | ---: | ---: | ---: |
| `forum_general` | 5 | 2 | 80% |
| `forum_advanced` | 20 | 10 | 80% |
| `forum_master` | 40 | 20 | 80% |
| `forum_elite` | 100 | Unlimited | 80% |

The plugin only limits replies. To prevent members from creating topics, set
Discourse's `create_topic_allowed_groups` site setting to the staff groups that
should retain that permission, and configure category security separately.

## User behavior

Each matching topic/group assignment grants its configured allowance on the
exact monthly anniversary of the subscription purchase:

- Creating a reply consumes one unit.
- Editing a reply consumes nothing.
- Soft-deleting or permanently deleting a reply does not return a unit.
- Unused replies carry forward up to the assignment's carryover cap. For
  example, using 2 of 5 leaves 3 unused replies; with a cap of 2, the next
  eligible cycle starts with 7 available. If only 1 reply were unused, that 1
  reply would carry forward. A blank cap preserves unlimited carryover.
- If Django removes the user from the assigned group, all available replies and
  carryover for that group are removed immediately.
- A July 25 purchase renews its allowance on August 25 at the same time, then
  September 25, while that subscription remains active.
- A subscription ending exactly at its next anniversary does not receive a new
  allowance at the same instant. A renewal/new purchase starts a fresh ledger
  from the new purchase timestamp.
- Administrators and moderators bypass every rule.
- Private messages and non-regular system posts are not counted.

At the configured threshold, the topic explains the cycle/carryover breakdown,
remaining count, rollover behavior, subscription-expiration reset, and next
credit date. At the limit, the topic's reply controls are disabled, a compact
status icon appears beside the bottom topic controls with an explanatory
hover/focus tooltip, and the server rejects any crafted or concurrent extra
request. An open topic refreshes its state automatically at the next credit
boundary.

If a user matches more than one configured group, every matching assignment is
reported and enforced independently. The plugin does not choose or combine a
"highest" or "lowest" tier. The current NEoWaveChart synchronization assigns
one forum tier group at a time, so normal subscribers match one tier rule.

## Database migration

The installation migration creates:

- `topic_reply_limit_rules`: one unique `(topic_id, group_id)` assignment with
  positive `reply_limit`, `warning_percentage` from 1 through 99, an optional
  non-negative `carryover_limit`, and timestamps.
- `topic_reply_limit_entitlements`: the current authoritative Django
  subscription ID, user/group mapping, exact purchase timestamp, expiration,
  and revocation marker.
- `topic_reply_limit_rule_revisions`: append-only effective-dated rule values,
  allowing edits to update the active cycle immediately without rewriting
  completed historical cycles.
- `topic_reply_limit_cycle_usages`: immutable subscription-cycle ledger rows,
  including exact cycle bounds, subscription ID, allowance, carry-in,
  created-reply count, and last reply timestamp.
- `topic_reply_limit_rule_periods`, `topic_reply_limit_membership_periods`, and
  `topic_reply_limit_period_usages`: pre-2.0 calendar-month rows retained
  untouched for rollback and audit safety; they are no longer enforced.
- `topic_reply_limit_usages`: the pre-1.1 lifetime rows retained untouched for
  zero-downtime rollout and rollback/audit safety; they are no longer enforced.

Discourse convention is followed by indexing logical references without adding
database foreign keys to core tables. Plugin callbacks remove orphaned rows when
core group, user, or topic records are permanently destroyed. Soft-deleted
topics retain rules so restoration is lossless. Deleting a rule intentionally
retains usage, so recreating the rule cannot restore consumed quota.

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for transaction and lifecycle details.
The three implementation passes are summarized in
[REVIEW_NOTES.md](docs/REVIEW_NOTES.md).

## API

Administrative endpoints use normal Discourse administrator authentication and
CSRF/API-key protections:

- `GET /admin/plugins/discourse-topic-reply-limits/rule-sets.json`
- `GET /admin/plugins/discourse-topic-reply-limits/rule-sets/:topic_id.json`
- `POST /admin/plugins/discourse-topic-reply-limits/rule-sets.json`
- `PUT /admin/plugins/discourse-topic-reply-limits/rule-sets/:topic_id.json`
- `DELETE /admin/plugins/discourse-topic-reply-limits/rule-sets/:topic_id.json`
- `GET /admin/plugins/discourse-topic-reply-limits/usage.json`
- `PUT /admin/plugins/discourse-topic-reply-limits/entitlements/sync.json`

The usage endpoint accepts `q`, `page`, and `per_page` parameters. Search
matches usernames, display names, topic titles, and group names. Page size
defaults to 50 and is capped at 100.

Create/update body:

```json
{
  "rule_set": {
    "topic_id": 123,
    "assignments": [
      {
        "group_id": 45,
        "reply_limit": 20,
        "warning_percentage": 80,
        "carryover_limit": 10
      }
    ]
  }
}
```

`carryover_limit` accepts `0` through `1000000`. Omit it or send `null` to keep
unlimited carryover for that assignment.

A logged-in user can request their own guardian-protected state for a visible
topic:

```text
GET /topic-reply-limits/topics/:topic_id/status.json
```

The endpoint never exposes another user's usage.

For rule integrations, create a granular Discourse API key and select the
plugin-provided `topic reply limits / read rules` and/or `manage rules` scopes.
Use `topic reply limits / read usage` for the usage report. The acting API user
must still be an administrator. Avoid a global-scope key.

The Django synchronization key additionally needs only
`topic reply limits / sync entitlements`. The endpoint accepts at most 500
records per request:

```json
{
  "entitlements": [
    {
      "user_external_id": "42",
      "entitlement_id": "781",
      "group_name": "forum_master",
      "starts_at": "2026-07-25T14:30:00+00:00",
      "ends_at": "2026-08-25T14:30:00+00:00"
    }
  ]
}
```

Send `entitlement_id: null` with the external user ID to revoke an expired
subscription. Unknown Discourse SSO users are reported and safely retried by
the next reconciliation.

## Subscription integration

Django remains the subscription/tier/time authority; Discourse remains the
reply-ledger and enforcement authority. NEoWaveChart now sends the selected
subscription entitlement after subscription changes and reconciles all users
every five minutes. No reset cron job is required: Discourse materializes the
correct anniversary cycle atomically when a topic is viewed or a reply is
created, so a delayed background job cannot miss a boundary. See
[DJANGO_INTEGRATION.md](docs/DJANGO_INTEGRATION.md).

## Operations

- Rule create/update/delete actions are recorded as custom staff actions.
- Disabling the site setting immediately stops enforcement and removes the
  client payload without deleting rules or counters.
- Re-enabling resumes active-subscription usage. A membership that expired while
  the plugin was enabled has no retained allowance or carryover.
- Database backups include all plugin tables through the normal Discourse
  backup process.

## License

MIT
