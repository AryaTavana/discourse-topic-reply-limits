# Changelog

## 2.0.1

- Apply reply-limit and warning-percentage edits immediately to every active
  subscription cycle while retaining its created-reply count and carryover.
- Preserve the final applicable rule revision for completed historical cycles,
  so later edits cannot rewrite old ledgers.
- Show the exact localized subscription end date when another allowance is not
  scheduled before expiration.

## 2.0.0

- Anchor every allowance cycle to the exact Django subscription purchase
  timestamp instead of the UTC calendar month.
- Add an admin-only, granular-scope entitlement sync API for subscription ID,
  tier group, start time, end time, and revocation.
- Start a new subscription with a fresh ledger; retain unlimited carryover only
  across cycles of the same active subscription.
- Handle end-of-month anniversaries without drift (January 31 → February
  28/29 → March 31).
- Show exact next-credit times in the user's local browser timezone and show a
  renewal explanation when the subscription ends before another credit.
- Add exact subscription-cycle dates to the admin usage report.
- Retain the former UTC-calendar ledger untouched for rollback and audit.

## 1.2.0

- Add an admin-only **User usage** page with current balances for every active
  user, topic, and group assignment.
- Show monthly allowance, carryover, total available, replies used this month,
  remaining replies, reached status, and last reply time.
- Add bounded server-side search and pagination plus a granular read-usage API
  key scope.

## 1.1.4

- Add a compact reached-limit indicator beside the bottom topic controls.
- Show an accessible hover/focus tooltip explaining that the topic reply limit
  has been reached.

## 1.1.3

- Replace the unreliable relative reset label with an explicit localized UTC
  date and time in both warning and reached-limit notices.
- Ensure notices never describe a future monthly reset as “just now.”

## 1.1.2

- Render the next monthly credit time as Discourse's live relative-date element
  instead of displaying its escaped HTML markup in warning and limit notices.
- Add frontend regression coverage for both notice states.

## 1.1.1

- Remove all available and carried replies when subscription-group membership
  ends.
- Start a later subscription with a fresh monthly allowance, including when the
  user rejoins the same group during the same UTC month.
- Ignore replies created before the current continuous subscription membership
  when reconciling its monthly usage.
- Explain subscription-expiration resets in user notices and the admin form.

## 1.1.0

- Change reply limits from lifetime quotas to UTC calendar-month allowances.
- Carry every unused reply into the next eligible month without a cap.
- Track subscription-group membership intervals so inactive months receive no
  credit while previously earned balances remain frozen.
- Snapshot rule values by month; administrator edits apply to the next monthly
  credit instead of changing an allowance already granted.
- Show monthly allowance, carryover, remaining replies, and the next credit date
  in accessible warning and reached-limit notices.
- Refresh open topic pages automatically when the next allowance is credited.
- Preserve the former lifetime table untouched while monthly usage is
  rebuilt from current-month posts, including deleted posts.

## 1.0.5

- Redesign warning and reached-limit notices with high-contrast, theme-aware
  colors that remain readable in light and dark color schemes.
- Improve notice hierarchy with prominent icons, titles, messages, and a
  separately emphasized remaining-reply count.
- Add appropriate live-region semantics for warning and blocking states.

## 1.0.4

- Fix blank Create and Edit rule cards on current stable Discourse by rendering
  the rule form in `AdminConfigAreaCard`'s required named content block.
- Add an acceptance regression test that verifies the complete create form is
  present inside the admin card.

## 1.0.3

- Fix the blank Reply limit rules tab on current stable Discourse by removing
  an unavailable admin filter component that prevented the admin JavaScript
  bundle from loading.
- Preserve topic-title filtering with a native tracked search field.

## 1.0.2

- Add an admin-only HTML fallback for the nested Reply limit rules routes so
  direct navigation and browser refreshes load the Discourse application shell
  instead of the server-side 404 page.

## 1.0.1

- Fix modern Discourse Admin route, controller, and template module placement so
  the Reply limit rules tab renders and survives a direct page refresh.
- Add a direct-navigation acceptance regression test for the nested plugin
  administration route.

## 1.0.0

- Initial production release.
