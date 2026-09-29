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

console.log(
  `[iOS 26 compatibility] ExpoModulesJSI patched: ${swiftFilesUpdated} Swift files, ` +
    `${patchedScheduler === schedulerSource ? 0 : 1} C++ header.`,
);
