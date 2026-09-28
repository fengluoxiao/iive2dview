import { NativeScriptConfig } from '@nativescript/core';

export default {
  // Must match the App ID covered by the enterprise provisioning profile.
  id: process.env.IOS_BUNDLE_ID || 'org.nativescript.nativevue',
  appPath: 'app',
  appResourcesPath: 'App_Resources',
  android: {
    v8Flags: '--expose_gc',
    markingMode: 'none'
  }
} as NativeScriptConfig;
