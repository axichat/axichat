## Calendar Feature Render Guidance

- When building or refactoring calendar surfaces (timelines, tabbed panes, animated cards), prefer custom `RenderBox` implementations to coordinate layout, painting, gestures, and semantics in one place.
- Do **not** rely on `addPostFrameCallback`, `findRenderObject`, or global keys for geometry. Compute measurements inside `performLayout` and drive animations from controller values like `TabContainer`’s `RenderTabFrame`.
- Keep the widget layer declarative: expose configuration only, delegate imperative work to render objects or dedicated services.
- Reference `docs/tab_container_study.md` before introducing new calendar UI to stay aligned with the `tab_container` approach.
