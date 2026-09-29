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

function replaceRequired(filePath, from, to, description) {
  const source = fs.readFileSync(filePath, 'utf8');
  if (source.includes(to)) return false;
  if (!source.includes(from)) {
    throw new Error(`Unable to apply ${description}: ${filePath}`);
  }
  fs.writeFileSync(filePath, source.replace(from, to));
  return true;
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
const patchedPromise = promiseSource.replace(
  /(@JavaScriptActor\r?\n[ \t]*private final class LongLivedState: LongLivedObject \{\r?\n)/,
  '$1    nonisolated init() {}\n',
);
if (patchedPromise === promiseSource && !promiseSource.includes('nonisolated init() {}')) {
  throw new Error(`Unable to apply JavaScriptPromise initializer patch: ${promiseFile}`);
}
if (patchedPromise !== promiseSource) fs.writeFileSync(promiseFile, patchedPromise);

console.log(
  `[iOS 26 compatibility] ExpoModulesJSI patched: ` +
    `${patchedScheduler === schedulerSource ? 0 : 1} header, ` +
    `${regexPatched ? 1 : 0} regex, ` +
    `${patchedPromise === promiseSource ? 0 : 1} initializer.`,
);
