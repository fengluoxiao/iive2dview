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
- [ ] Native live PiP with AVKit, lifecycle/error handling and actual rendered frames. User explicitly chose: freeze last frame in background; resume live model on returning to app. Apple prohibits Metal command submission in background.
- [ ] Lint, TypeScript, meaningful behavior checks, native CI build, UI visual verification, unsigned IPA delivery.

## Constraints

- iOS 18+, iPhone 14 Pro Max; current device reports iOS 27.2 beta.
- Native build through existing GitHub Actions, not local macOS or certificate changes.
- Do not touch untracked `expo-live2d/.verification-deps/`.
- Do not revert folder `asCopy:NO` + security scoped coordinated copying, or parameter snapshot fix.
- Awaiting user confirmation is not required to implement scope already approved.

## Progress

- All checklist features now have implementations in `App.tsx`, `studio.ts`, and the native Metal host. Checkboxes above remain acceptance gates, not claims of device testing.
- UI-only browser QA at 430×932 and 1280×800 verified the dock, control sheet, sidebar and nine face controls. Corrected compact button sizing and slider zero positioning. This preview does not test native rendering.
- Direction selection, filename fallback, face parameter mappings and labels pass four Node tests. TypeScript and Expo lint are required in CI before native compilation.
- Final native Expo build for `3919655` succeeded: https://github.com/fengluoxiao/iive2dview/actions/runs/36558031215 . Unsigned artifact: `live2d-expo-metal-unsigned-ipa` (11028307456).
- Final UI interaction checks: dragging the face-angle slider changed 0 to 16, face reset returned it to 0, the mobile sheet closed correctly, and the wide layout had no horizontal overflow. Stage rotation now preserves zoom.
- PiP stops new Metal submissions while inactive. It retains the last sample in the background and resumes captures when active; PiP captures are capped at 30 FPS and a 960-pixel longest edge, while PNG export keeps render resolution.
- Device acceptance still required: model import/relaunch, all controls with a real model, PNG sharing, PiP start/background/foreground, and gesture regression. The latest user-verified baseline before the full Studio port is `68d8b8c` (Expo Run 32).
