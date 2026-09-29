# Local model folders

## iOS

Launch the app once. In Files, open **On My iPhone/iPad → Live2D Metal → models**.
Copy complete extracted model folders there. For example:

```
models/
  sakiko/
    casual_spring_01/
      character.model3.json
      character.moc3
      textures/
      motions/
```

All nested `.model3.json` files are listed. Keep every referenced file in its original relative location.
Return to the app to scan, or use **刷新模型** in the control panel after copying finishes.
Existing imported models in Application Support remain readable without moving or deleting them.
New ZIP/folder imports go into Documents/models, inside a unique import subfolder.
ZIPs manually copied into models must be extracted first; the existing Import ZIP button still extracts archives.

## Android

This build provides directory management only; the native Android model renderer is not implemented yet.
Open the Android system document browser (or a file manager with Storage Access Framework support).
Its location sidebar includes **Live2D 模型**. This location is the app's private `files/models` directory,
exposed through a DocumentsProvider. It supports creating folders, copying files in, renaming and deletion.
Only models is exposed, not other private app files. No all-files storage permission is requested.
Some vendor file managers do not show document providers; use the system document browser in that case.

Copy extracted model folders into this location, then return to the app or tap **刷新模型**.
The Android screen lists discovered model paths and reports inaccessible subdirectories.
The APK build includes its JS bundle and does not need Metro. It uses the generated project's development
signing configuration; it is a test artifact, not a stable production signing identity for future updates.

## Data and signing

Uninstalling deletes these app-owned files. Keep originals elsewhere.
Changing the Bundle ID/package creates a separate application sandbox; files do not transfer automatically.
The iOS Bundle ID is restored to `com.fengluo.live2dmetal` as requested. This directory workflow removes the
need to select an external folder but does not remove Apple's code-signing/provisioning requirements.
