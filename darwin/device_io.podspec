Pod::Spec.new do |s|
  s.name             = 'device_io'
  s.version          = '0.0.0'
  s.summary          = 'Cross-platform file picking, saving, sharing, opening and linking for Flutter.'
  s.description      = 'The native half of the links door: in-place document picking, bookmarks, security scopes.'
  s.homepage         = 'https://github.com/whuppi/device_io'
  s.license          = { :type => 'MIT' }
  s.author           = { 'whuppi' => 'dev@whuppi.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'device_io/Sources/device_io/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.9'
end
