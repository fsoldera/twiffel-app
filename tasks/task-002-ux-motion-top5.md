# Task 002 — UX motion Top 5 (from emulator review)

Implement the five highest-impact UX / motion improvements from the
Flutter UX analysis walkthrough (wizard → loading → results → menu).

Risk: **medium**. Human review before merge.

---

## Goal

```text
- Loading → results feels like a finished analysis, not a hard cut.
- Verdict expand focuses attention (swipe hint dims/hides).
- Wizard steps animate forward/back while sticky nav stays fixed.
- Generate analysis shows in-flight feedback; long waits offer Cancel.
- Start over / system back confirm before discarding results.
- Respect Reduce Motion (MediaQuery.disableAnimations).
- Pros/Cons and Option A/B switches use purposeful list motion (slide+fade,
  animated chips/dots), not instant content jumps.
```

---

## Required context

- `lib/src/pages/decision_form_page.dart`
- `lib/src/pages/analysis_page.dart`
- `lib/src/pages/decision_copy.dart`
- `lib/src/state/session_controller.dart`
- `lib/src/widgets/loading_animation.dart`
- `lib/src/widgets/sticky_nav_buttons.dart`
- `harness/writing-style.md` (no `--` / `—` in UI prose)

---

## Acceptance criteria

### 1. Loading → results handoff

- [x] Loading screen shows the user's comparison (or single target) under the rotating line.
- [x] Pros/Cons list items stagger in on first results appear (skipped under Reduce Motion).
- [x] Loading mark respects Reduce Motion (static mark when animations disabled).

### 2. Verdict chrome

- [x] While Summary Verdict is expanded, "Swipe to switch" (+ dots) is dimmed or hidden.
- [x] Start over / Share remain usable.

### 3. Wizard step motion

- [x] Step changes use a short slide+fade (or fade-only under Reduce Motion).
- [x] Sticky PREV / NEXT / Generate analysis stays fixed (not part of the slide).

### 4. Generate feedback + Cancel

- [x] Generate analysis keeps the existing button loading state when submitting.
- [x] After ~8s on the wait screen, a Cancel control appears.
- [x] Cancel aborts applying late AI results and returns to the form (`SessionController` generation/cancel).

### 5. Confirm Start over

- [x] Start over and system back on analysis show a confirm dialog before reset.
- [x] Copy uses commas, not dashes (`harness/writing-style.md`).

---

## Sensors

```text
flutter analyze
flutter test
```

---

## Out of scope

```text
- Splash redesign
- Share sheet motion
- Backend / Worker changes
- New package dependencies (prefer built-in Flutter animations)
```
