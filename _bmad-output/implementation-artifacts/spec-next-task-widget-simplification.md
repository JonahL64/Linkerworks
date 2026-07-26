---
title: 'Simplify Today rows and next-task widget'
type: 'feature'
created: '2026-07-24'
status: 'done'
route: 'one-shot'
---

# Simplify Today rows and next-task widget

## Intent

**Problem:** Times added visual clutter to Today, while the widget mixed progress with the next action.

**Approach:** Show titles only in Today and make every widget family present the next incomplete task without a time or progress count.

## Suggested Review Order

- Today rows retain task state and details but remove the inline time display.
  [`ContentView.swift:242`](../../Linkerworks/ContentView.swift#L242)

- Completion saves immediately refresh the next-task widget.
  [`ContentView.swift:315`](../../Linkerworks/ContentView.swift#L315)

- Widget data selects the same scheduled incomplete tasks as Today.
  [`LinkerworksWidget.swift:74`](../../LinkerworksWidget/LinkerworksWidget.swift#L74)

- Home and lock-screen families render task title only, with no time or progress.
  [`LinkerworksWidget.swift:180`](../../LinkerworksWidget/LinkerworksWidget.swift#L180)
