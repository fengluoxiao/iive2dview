const fs = require('fs');
const path = require('path');

const packageRoot = path.join(
  process.cwd(),
  'node_modules',
  'expo-modules-jsi',
  'apple',
  'Sources',
);

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(entryPath) : [entryPath];
  });
}

if (!fs.existsSync(packageRoot)) {
  throw new Error(`expo-modules-jsi source directory was not found: ${packageRoot}`);
}

let swiftFilesUpdated = 0;
for (const filePath of walk(packageRoot).filter((file) => file.endsWith('.swift'))) {
  const source = fs.readFileSync(filePath, 'utf8');
  const patched = source.replace(/weak let runtime/g, 'weak var runtime');
  if (patched !== source) {
    fs.writeFileSync(filePath, patched);
    swiftFilesUpdated += 1;
  }
}

const schedulerHeader = path.join(
  packageRoot,
  'ExpoModulesJSI-Cxx',
  'include',
  'RuntimeScheduler.h',
);
const schedulerSource = fs.readFileSync(schedulerHeader, 'utf8');
const patchedScheduler = schedulerSource.replace(
  /SWIFT_RETURNS_RETAINED RuntimeScheduler/g,
  'RuntimeScheduler',
);
if (patchedScheduler === schedulerSource && schedulerSource.includes('SWIFT_RETURNS_RETAINED')) {
  throw new Error('Unable to apply the RuntimeScheduler Swift interop compatibility patch');
}
if (patchedScheduler !== schedulerSource) {
  fs.writeFileSync(schedulerHeader, patchedScheduler);
}

const uncheckedSendableTypes = [
  [
    path.join(packageRoot, 'ExpoModulesJSI', 'Runtime', 'JavaScriptPropNameID.swift'),
    'public final class JavaScriptPropNameID: JavaScriptType {',
    'public final class JavaScriptPropNameID: JavaScriptType, @unchecked Sendable {',
  ],
  [
    path.join(packageRoot, 'ExpoModulesJSI', 'Runtime', 'Values', 'JavaScriptError.swift'),
    'public final class JavaScriptError: Error, Sendable {',
    'public final class JavaScriptError: Error, @unchecked Sendable {',
  ],
  [
    path.join(packageRoot, 'ExpoModulesJSI', 'Runtime', 'Values', 'JavaScriptValue.swift'),
    'public final class JavaScriptValue: JavaScriptType, Equatable, Escapable {',
    'public final class JavaScriptValue: JavaScriptType, Equatable, Escapable, @unchecked Sendable {',
  ],
];

let sendableTypesUpdated = 0;
for (const [filePath, originalDeclaration, patchedDeclaration] of uncheckedSendableTypes) {
  const source = fs.readFileSync(filePath, 'utf8');
  const patched = source.replace(originalDeclaration, patchedDeclaration);
  if (patched === source && !source.includes(patchedDeclaration)) {
    throw new Error(`Unable to apply the Swift Sendable compatibility patch: ${filePath}`);
  }
  if (patched !== source) {
    fs.writeFileSync(filePath, patched);
    sendableTypesUpdated += 1;
  }
}

const packageManifest = path.join(path.dirname(packageRoot), 'Package.swift');
const manifestSource = fs.readFileSync(packageManifest, 'utf8');
const swift5Manifest = manifestSource.replace(
  'swiftLanguageModes: [.v6],',
  'swiftLanguageModes: [.v5],',
);
const patchedManifest = swift5Manifest
  .replace(
    '        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),\n',
    '',
  )
  .replace(
    '        .enableUpcomingFeature("InferIsolatedConformances"),\n',
    '',
  )
  .replace(
    '          "-enable-library-evolution",\n',
    '          "-enable-library-evolution",\n          "-enable-bare-slash-regex",\n',
  );
if (
  !patchedManifest.includes('swiftLanguageModes: [.v5],') ||
  !patchedManifest.includes('"-enable-bare-slash-regex",') ||
  patchedManifest.includes('.enableUpcomingFeature("NonisolatedNonsendingByDefault")') ||
  patchedManifest.includes('.enableUpcomingFeature("InferIsolatedConformances")')
) {
  throw new Error('Unable to apply the Swift 6 concurrency compatibility patch');
}

const promiseFile = path.join(
  packageRoot,
  'ExpoModulesJSI',
  'Runtime',
  'Values',
  'JavaScriptPromise.swift',
);
const promiseSource = fs.readFileSync(promiseFile, 'utf8');
const patchedPromise = promiseSource.replace(
  /@JavaScriptActor\r?\n[ \t]*private final class LongLivedState/,
  '  private final class LongLivedState',
);
if (patchedPromise === promiseSource && !promiseSource.includes('  private final class LongLivedState')) {
  throw new Error('Unable to apply the JavaScriptPromise actor compatibility patch');
}
if (patchedPromise !== promiseSource) {
  fs.writeFileSync(promiseFile, patchedPromise);
}
if (patchedManifest !== manifestSource) {
  fs.writeFileSync(packageManifest, patchedManifest);
}

console.log(
  `[iOS 26 compatibility] ExpoModulesJSI patched: ${swiftFilesUpdated} Swift files, ` +
    `${patchedScheduler === schedulerSource ? 0 : 1} C++ header, ` +
    `${sendableTypesUpdated} Sendable declarations, ` +
    `${patchedManifest === manifestSource ? 0 : 1} Swift package manifest.`,
);
