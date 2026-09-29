const { withEntitlementsPlist, withXcodeProject, createRunOncePlugin } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');
const plist = require('@expo/plist');

const name = 'Live2DWidget';
const group = 'group.com.fengluo.live2dmetal';
function withLive2DWidget(config) {
  config = withEntitlementsPlist(config, c => {
    c.modResults['com.apple.security.application-groups'] = [...new Set([
      ...(c.modResults['com.apple.security.application-groups'] || []), group,
    ])];
    return c;
  });
  return withXcodeProject(config, c => {
    const project = c.modResults;
    if (project.pbxTargetByName(name)) return c;
    const dir = path.join(c.modRequest.platformProjectRoot, name);
    fs.mkdirSync(dir, { recursive: true });
    for (const file of ['Live2DWidget.swift', 'Live2DWidgetReloader.swift']) {
      fs.copyFileSync(path.join(c.modRequest.projectRoot, 'widgets', file), path.join(dir, file));
    }
    fs.writeFileSync(path.join(dir, 'Info.plist'), plist.default.build({
      CFBundleDisplayName: 'Live2D 表情', CFBundleIdentifier: '$(PRODUCT_BUNDLE_IDENTIFIER)',
      CFBundleName: '$(PRODUCT_NAME)', CFBundleExecutable: '$(EXECUTABLE_NAME)',
      CFBundlePackageType: 'XPC!', CFBundleShortVersionString: c.version || '1.0.0',
      CFBundleVersion: c.ios?.buildNumber || '1',
      NSExtension: { NSExtensionPointIdentifier: 'com.apple.widgetkit-extension' },
    }));
    fs.writeFileSync(path.join(dir, `${name}.entitlements`), plist.default.build({
      'com.apple.security.application-groups': [group],
    }));
    const main = project.getFirstTarget().uuid;
    const target = project.addTarget(name, 'app_extension', name, `${c.ios.bundleIdentifier}.widget`);
    project.addBuildPhase([`${name}/Live2DWidget.swift`], 'PBXSourcesBuildPhase', 'Sources', target.uuid);
    project.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', target.uuid);
    const groupKey = project.addPbxGroup([], name, name).uuid;
    project.addToPbxGroup(groupKey, project.getFirstProject().firstProject.mainGroup);
    project.addSourceFile('Live2DWidgetReloader.swift', { target: main }, groupKey);
    const list = project.pbxXCConfigurationList()[target.pbxNativeTarget.buildConfigurationList];
    for (const item of list.buildConfigurations) {
      Object.assign(project.pbxXCBuildConfigurationSection()[item.value].buildSettings, {
        INFOPLIST_FILE: `${name}/Info.plist`, CODE_SIGN_ENTITLEMENTS: `${name}/${name}.entitlements`,
        IPHONEOS_DEPLOYMENT_TARGET: '18.0', SWIFT_VERSION: '5.0', TARGETED_DEVICE_FAMILY: '"1,2"',
        APPLICATION_EXTENSION_API_ONLY: 'YES', GENERATE_INFOPLIST_FILE: 'NO',
        CURRENT_PROJECT_VERSION: c.ios?.buildNumber || '1', MARKETING_VERSION: c.version || '1.0.0',
      });
    }
    return c;
  });
}
module.exports = createRunOncePlugin(withLive2DWidget, 'with-live2d-widget', '1.0.0');
