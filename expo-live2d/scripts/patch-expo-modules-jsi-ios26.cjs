const fs = require('fs');
const path = require('path');

const packageRoot = path.join(
  process.cwd(),
  'node_modules',
  'expo-modules-jsi',
  'apple',
  'Sources',
);

if (!fs.existsSync(packageRoot)) {
  throw new Error(`expo-modules-jsi source directory was not found: ${packageRoot}`);
}

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(entryPath) : [entryPath];
  });
}

function replaceRequired(filePath, from, to, description) {
  const source = fs.readFileSync(filePath, 'utf8');
  if (source.includes(to)) return false;
  if (!source.includes(from)) {
    throw new Error(`Unable to apply ${description}: ${filePath}`);
  }
  fs.writeFileSync(filePath, source.replace(from, to));
  return true;
}

let weakReferencesPatched = 0;
for (const filePath of walk(packageRoot).filter((file) => file.endsWith('.swift'))) {
  const source = fs.readFileSync(filePath, 'utf8');
  const patched = source.replace(/weak let runtime/g, 'weak var runtime');
  if (patched !== source) {
    fs.writeFileSync(filePath, patched);
    weakReferencesPatched += 1;
  }
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

let sendableTypesPatched = 0;
for (const [filePath, originalDeclaration, patchedDeclaration] of uncheckedSendableTypes) {
  if (replaceRequired(filePath, originalDeclaration, patchedDeclaration, 'Swift Sendable patch')) {
    sendableTypesPatched += 1;
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
if (
  patchedScheduler === schedulerSource &&
  schedulerSource.includes('SWIFT_RETURNS_RETAINED RuntimeScheduler')
) {
  throw new Error(`Unable to apply RuntimeScheduler annotation patch: ${schedulerHeader}`);
}
if (patchedScheduler !== schedulerSource) fs.writeFileSync(schedulerHeader, patchedScheduler);

const runtimeFile = path.join(
  packageRoot,
  'ExpoModulesJSI',
  'Runtime',
  'JavaScriptRuntime.swift',
);
const regexPatched = replaceRequired(
  runtimeFile,
  '/^[a-zA-Z_$][a-zA-Z0-9_$]*$/',
  '#/^[a-zA-Z_$][a-zA-Z0-9_$]*$/#',
  'JavaScript identifier regex patch',
);

const promiseFile = path.join(
  packageRoot,
  'ExpoModulesJSI',
  'Runtime',
  'Values',
  'JavaScriptPromise.swift',
);
const promiseSource = fs.readFileSync(promiseFile, 'utf8');
let promisePatched = false;
if (!promiseSource.includes('nonisolated init() {}')) {
  const patchedPromise = promiseSource.replace(
    /(@JavaScriptActor\r?\n[ \t]*private final class LongLivedState: LongLivedObject \{\r?\n)/,
    '$1    nonisolated init() {}\n',
  );
  if (patchedPromise === promiseSource) {
    throw new Error(`Unable to apply JavaScriptPromise initializer patch: ${promiseFile}`);
  }
  fs.writeFileSync(promiseFile, patchedPromise);
  promisePatched = true;
}
if (!fs.readFileSync(promiseFile, 'utf8').includes('nonisolated init() {}')) {
  throw new Error(`Unable to apply JavaScriptPromise initializer patch: ${promiseFile}`);
}

console.log(
  `[iOS 26 compatibility] ExpoModulesJSI patched: ` +
    `${weakReferencesPatched} weak references, ` +
    `${sendableTypesPatched} Sendable declarations, ` +
    `${patchedScheduler === schedulerSource ? 0 : 1} header, ` +
    `${regexPatched ? 1 : 0} regex, ` +
    `${promisePatched ? 1 : 0} initializer.`,
);
