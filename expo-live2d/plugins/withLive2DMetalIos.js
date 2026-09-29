const { withPodfile, createRunOncePlugin } = require('@expo/config-plugins');

const POD_LINES = [
  "  pod 'Live2DNativeMetal', :path => '../../native-vue/packages/live2d-native-metal'",
  "  pod 'ExpoLive2DHost', :path => '../ios-host'",
].join('\n');

function withLive2DMetalIos(config) {
  return withPodfile(config, (nextConfig) => {
    const contents = nextConfig.modResults.contents;
    if (contents.includes("pod 'ExpoLive2DHost'")) {
      return nextConfig;
    }

    const postInstall = /\n  post_install do \|installer\|/;
    if (!postInstall.test(contents)) {
      throw new Error('Unable to add the Live2D pods: Expo Podfile target block was not found.');
    }
    nextConfig.modResults.contents = contents.replace(
      postInstall,
      `\n${POD_LINES}\n\n  post_install do |installer|`,
    );
    return nextConfig;
  });
}

module.exports = createRunOncePlugin(withLive2DMetalIos, 'with-live2d-metal-ios', '1.0.0');
