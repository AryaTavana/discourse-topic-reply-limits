# Changelog

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
