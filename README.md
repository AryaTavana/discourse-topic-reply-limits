# discourse-topic-reply-limits

`discourse-topic-reply-limits` adds authoritative, per-topic reply quotas for
Discourse groups. Administrators manage rules in a dedicated modern Discourse
Admin interface. It does not replace Discourse category security and it does not
grant access to topics.

## Features

- One or more group-specific limits for any regular topic.
- Topic and group search/select controls in Discourse Admin.
- Configurable warning threshold per group (80% by default).
- Server-side enforcement for web, mobile, API, and email-created replies.
- Immediate client-side warning updates and reply-composer disabling.
- Staff bypass for administrators and moderators.
- Lifetime created-reply counters: deletion never restores quota and editing
  never consumes quota.
- Historical backfill: the first counter is initialized from all existing
  regular replies, including soft-deleted replies.
- Transaction-scoped locking, database uniqueness, and check constraints.
- Staff action audit entries for rule changes.
- Admin JSON rule API and a guardian-protected current-user status API.

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
4. Add one or more group assignments, each with its own reply limit and warning
   percentage.
5. Save the rule set.

For example, one topic can have these independent assignments:

| Group | Reply limit | Warning |
| --- | ---: | ---: |
| `forum_general` | 5 | 80% |
| `forum_advanced` | 20 | 80% |
| `forum_master` | 40 | 80% |
| `forum_elite` | 100 | 80% |

The plugin only limits replies. To prevent members from creating topics, set
Discourse's `create_topic_allowed_groups` site setting to the staff groups that
should retain that permission, and configure category security separately.

## User behavior

The counter is shared by a user and topic. It records how many regular replies
that user has created in that topic:

- Creating a reply consumes one unit.
- Editing a reply consumes nothing.
- Soft-deleting or permanently deleting a reply does not return a unit.
- Administrators and moderators bypass every rule.
- Private messages and non-regular system posts are not counted.

At the configured threshold, the topic shows the used percentage and exact
remaining count. At the limit, the topic's reply controls are disabled and the
server rejects any crafted or concurrent extra request.

If a user matches more than one configured group, every matching assignment is
reported and enforced independently. The plugin does not choose or combine a
"highest" or "lowest" tier. The current NEoWaveChart synchronization assigns
one forum tier group at a time, so normal subscribers match one tier rule.

## Database migration

The installation migration creates:

- `topic_reply_limit_rules`: one unique `(topic_id, group_id)` assignment with
  positive `reply_limit`, `warning_percentage` from 1 through 99, and timestamps.
- `topic_reply_limit_usages`: one unique `(user_id, topic_id)` lifetime counter,
  its last reply timestamp, and timestamps.

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

Create/update body:

```json
{
  "rule_set": {
    "topic_id": 123,
    "assignments": [
      { "group_id": 45, "reply_limit": 20, "warning_percentage": 80 }
    ]
  }
}
```

A logged-in user can request their own guardian-protected state for a visible
topic:

```text
GET /topic-reply-limits/topics/:topic_id/status.json
```

The endpoint never exposes another user's usage.

For server integrations, create a granular Discourse API key and select the
plugin-provided `topic reply limits / read rules` and/or `manage rules` scopes.
The acting API user must still be an administrator. Avoid a global-scope key.

## Subscription integration

No clock-based reset is implemented. That is intentional after reviewing the
NEoWaveChart subscription and Discourse group synchronization lifecycle. Django
remains the entitlement authority, while Discourse remains the posting and
counter authority. See [DJANGO_INTEGRATION.md](docs/DJANGO_INTEGRATION.md) for
the findings and the recommended future period-key design.

## Operations

- Rule create/update/delete actions are recorded as custom staff actions.
- Disabling the site setting immediately stops enforcement and removes the
  client payload without deleting rules or counters.
- Re-enabling resumes from retained lifetime usage.
- Database backups include both plugin tables through the normal Discourse
  backup process.

## License

MIT
