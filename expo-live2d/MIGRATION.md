# React Studio → native Metal migration

User goal: fully port the original React app, including its UI, to the working Expo/React Native iOS app. Do not call this complete based on compilation alone.

Source of truth: `../src/App.tsx`, `../src/styles.css`, `../src/live2d.ts` (local original files are ignored by this Git repository). Native destination uses Cubism Metal, never a WebView. Existing verified folder/ZIP imports, parameter overrides, one-finger pan and pinch must remain working.

## Acceptance checklist

- [ ] Dark Studio UI: original palette, typography hierarchy, top direction selector, stage grid, status toast, drawables and performance HUD, mobile dock, dismissible scrolling control sheet; wide screens use sidebar.
- [ ] Persistent local model library, import all model3.json entries from folders/ZIPs, character/outfit selection, useful import errors, restoration after restart. Local imports replace obsolete PC server root configuration.
- [ ] Native model metadata events and command bridge, with errors reported to UI.
- [ ] Motion groups, friendly names, C/L/R direction matching and linked idle direction, manual motion playback, automatic demo.
- [ ] Sequential looping idle motions and automatic blink toggle.
- [ ] Expression selection and clear expression.
- [ ] Nine face sliders matching original ranges; reset clears overrides so animation/blink resume.
- [ ] Pan, pinch and scale slider agree; mirror; reset pose/position/expression without resetting zoom.
- [ ] Auto/smooth/sharp quality modes with actual drawable sizing; real frame/update metrics.
- [ ] PNG export via native Metal capture and iOS share sheet.
- [ ] Native live PiP with AVKit, lifecycle/error handling and actual rendered frames.
- [ ] Lint, TypeScript, meaningful behavior checks, native CI build, UI visual verification, unsigned IPA delivery.

## Constraints

- iOS 18+, iPhone 14 Pro Max; current device reports iOS 27.2 beta.
- Native build through existing GitHub Actions, not local macOS or certificate changes.
- Do not touch untracked `expo-live2d/.verification-deps/`.
- Do not revert folder `asCopy:NO` + security scoped coordinated copying, or parameter snapshot fix.
- Awaiting user confirmation is not required to implement scope already approved.

## Progress

- Source inventory complete. Current Expo UI only has three sliders and import/reset; most original features still need implementation.
- Latest user-verified baseline: commit `68d8b8c`, Expo Actions Run 32.
