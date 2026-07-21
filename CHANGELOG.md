# Changelog

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
