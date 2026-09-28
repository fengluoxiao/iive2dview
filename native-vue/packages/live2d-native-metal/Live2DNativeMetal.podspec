Pod::Spec.new do |spec|
  spec.name = 'Live2DNativeMetal'
  spec.version = '0.1.0'
  spec.summary = 'NativeScript bridge for the Cubism Native Metal sample renderer.'
  spec.homepage = 'https://www.live2d.com/'
  spec.license = { :type => 'Live2D Open Software License' }
  spec.authors = { 'Live2D' => 'https://www.live2d.com/' }
  spec.platform = :ios, '16.0'
  spec.source = { :path => '.' }
  spec.requires_arc = false

  sdk = 'vendor/Cubism'
  sample = "#{sdk}/Samples/Metal/Demo/proj.ios.cmake/src"

  spec.source_files = [
    'src/**/*.{h,m,mm,cpp,hpp}',
    "#{sdk}/Framework/src/**/*.{cpp,hpp,mm}",
    "#{sample}/**/*.{h,m,mm}",
  ]
  spec.exclude_files = [
    "#{sdk}/Framework/src/Rendering/D3D9/**/*",
    "#{sdk}/Framework/src/Rendering/D3D11/**/*",
    "#{sdk}/Framework/src/Rendering/OpenGL/**/*",
    "#{sdk}/Framework/src/Rendering/Vulkan/**/*",
    "#{sample}/main.m",
    "#{sample}/AppDelegate.{h,mm}",
    "#{sample}/SceneDelegate.{h,mm}",
  ]
  spec.resources = [
    "#{sdk}/Framework/src/Rendering/Metal/Shaders/*",
    "#{sample}/Shaders/*",
  ]
  spec.vendored_libraries = "#{sdk}/Core/lib/ios/Release-iphoneos/libLive2DCubismCore.a"
  spec.dependency 'SSZipArchive', '~> 2.5'
  spec.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_ENABLE_OBJC_ARC' => 'NO',
    'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_TARGET_SRCROOT}/vendor/Cubism/Core/include ${PODS_TARGET_SRCROOT}/vendor/Cubism/Framework/src ${PODS_TARGET_SRCROOT}/vendor/Cubism/Samples/Metal/Demo/proj.ios.cmake/src ${PODS_TARGET_SRCROOT}/vendor/Cubism/Samples/Metal/thirdParty/stb',
    'OTHER_LDFLAGS' => '$(inherited) -lc++',
  }
  spec.frameworks = 'CoreGraphics', 'Foundation', 'Metal', 'MetalKit', 'QuartzCore', 'UIKit'
end
