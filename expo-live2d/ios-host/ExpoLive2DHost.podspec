Pod::Spec.new do |spec|
  spec.name = 'ExpoLive2DHost'
  spec.version = '1.0.0'
  spec.summary = 'React Native host view for the native Live2D Metal renderer.'
  spec.homepage = 'https://github.com/fengluoxiao/iive2dview'
  spec.license = { :type => 'MIT' }
  spec.authors = { 'fengluoxiao' => 'https://github.com/fengluoxiao' }
  spec.platform = :ios, '16.0'
  spec.source = { :path => '.' }
  spec.source_files = '**/*.{h,m,mm}'
  spec.requires_arc = true
  spec.dependency 'React-Core'
  spec.dependency 'Live2DNativeMetal'
end
