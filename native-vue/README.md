# Live2D Native Vue

This is the iOS-native replacement for the browser stream viewer. NativeScript-Vue owns the controls and embeds the official Cubism Native Metal sample renderer. The model is rendered on the phone GPU through Metal, so no browser canvas, WebRTC, HLS, or video decode buffer is involved.

## Included

- Cubism SDK for Native R5 Core, Framework, and Metal sample under `vendor/`
- A NativeScript iOS bridge in `packages/live2d-native-metal`
- GitHub Actions macOS build definition at `../.github/workflows/ios-native.yml`

## Import a model

The app does not package a character model. Tap `导入模型` and choose either a model folder or a ZIP from the iOS Files app. The importer copies or extracts it to the app's private `Application Support/Live2DModels` directory and recursively loads the first `.model3.json` it finds.

Keep the original model directory layout intact. The selected folder or ZIP must contain its `.moc3`, textures, motions, expressions, physics files, and `.model3.json` with their original relative paths.

## Local validation on Windows

`npm run check` validates the Vue/TypeScript layer. Windows cannot compile an iOS Metal target.

## macOS CI and device installation

The workflow builds the iOS target on a macOS runner. `workflow_dispatch` has an unsigned mode and an enterprise-signed IPA mode. Keep this repository private if it contains Cubism SDK binaries and model assets.

For an enterprise-signed build, set these repository variables:

- `IOS_BUNDLE_ID`: exact App ID suffix covered by the enterprise profile
- `IOS_TEAM_ID`: Apple Developer team identifier
- `IOS_SIGNING_IDENTITY`: exact identity reported by `security find-identity -v -p codesigning`

Set these repository secrets:

- `IOS_ENTERPRISE_P12_BASE64`: Base64 of the enterprise distribution `.p12`
- `IOS_ENTERPRISE_P12_PASSWORD`: password used to export that `.p12`
- `IOS_ENTERPRISE_PROFILE_BASE64`: Base64 of the matching In-House `.mobileprovision`

The workflow imports the material into a temporary keychain and validates that the profile covers `IOS_BUNDLE_ID` before compiling. Do not commit a certificate, profile, or their passwords.

The app has a separate `Live2DMetalHostView` instead of a WebView. `ParamAngleX`, `ParamEyeLOpen`, `ParamEyeROpen`, and `ParamMouthOpenY` are sent straight from the Vue sliders into the native Cubism model.
