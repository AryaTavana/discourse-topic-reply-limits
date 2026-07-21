# Senior review record

Three implementation review passes were performed against the latest stable
Discourse checkout.

## Pass 1 — architecture, database, and concurrency

Reviewed rule/usage ownership, reply lifecycle hooks, soft deletion, schema
constraints, counter backfill, and concurrent first replies.

Improvements made:

- replaced unsafe first-row-only locking with a transaction-scoped PostgreSQL
  advisory lock plus row lock;
- kept the increment in the same transaction as post creation so failure rolls
  both back;
- guarded enforcement and serialization with the enable setting;
- corrected automatic/pseudogroup matching through `User#in_any_groups?`;
- corrected serializer and route constants found by booting the real app;
- verified unique indexes and database check constraints after migration.

## Pass 2 — compatibility, performance, and UX

Reviewed Glimmer/FormKit structure, route resolution, topic/group selectors,
responsive table markup, warning updates, composer state, error handling, query
shape, and plugin disable/restore behavior.

Improvements made:

- corrected FormKit validation syntax and yielded-block usage;
- corrected plugin module imports and selected-topic tracking;
- verified all frontend modules with a full Rolldown production build;
- limited client-side increments to replies in the loaded topic;
- added create/update success feedback and explicit destructive confirmation;
- made lifetime usage continue independently of temporary group changes once a
  topic is governed, while keeping staff enforcement bypassed.

## Pass 3 — security and integration boundaries

Reviewed privileged routes, IDOR exposure, CSRF/API authentication, nested input
validation, DOM injection/navigation sinks, secrets, SQL binding, guardian
checks, auditability, and Django-to-Discourse trust boundaries.

Improvements made:

- retained admin enforcement at route, controller, and service-policy layers;
- retained guardian checks on the current-user status endpoint and exposed no
  arbitrary user lookup;
- added granular API-key scopes for reading and managing rule sets;
- verified the frontend uses escaped Glimmer bindings and contains no direct DOM
  HTML/code-execution sinks or embedded secrets;
- kept advisory-lock SQL parameterized;
- documented dedicated credentials, HTTPS, reconciliation, expiry-boundary, and
  future signed/idempotent entitlement-period requirements for Django.

No time-based reset was added. The absence of a stable cross-system entitlement
period identifier makes an inferred reset less correct and less secure than the
lifetime behavior requested for this version.
