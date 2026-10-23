---
name: emil-kowalski
description: Emil Kowalski's interaction design, micro-interactions, and fluid UI principles. Enforces natural tactile feedback, spring easing curves, micro-interactions, and seamless spatial continuity.
---

# Emil Kowalski Interaction & Micro-Interaction Principles

1. **Physical Continuity & Motion**:
   - Layouts must feel grounded and predictable; avoid jarring layout shifts or components popping into view without context.
   - Use physical spring easing curves: `cubic-bezier(0.16, 1, 0.3, 1)` or snappy 150-200ms transitions.
   - Never use `scale(0)` or heavy zoom entries that disorient the user.

2. **Tactile Feedback & States**:
   - Every interactive element (Button, OptionList, Input) must have distinct, delightful states: `default`, `hover`, `focus`, `active`, and `disabled`.
   - Focus rings should be crisp, high-contrast, and never cut off.
   - Feedback on action must be immediate (< 16ms perception threshold).

3. **Spatial Ergonomics**:
   - Navigation actions (Next / Back) must remain spatially consistent across all screens.
   - Primary forward action always lives on the bottom-right; secondary back action lives on the bottom-left.
   - Prevent scroll container bleed: child scroll panes (e.g. OptionLists or Logs) must not hijack the parent view unexpectedly.
