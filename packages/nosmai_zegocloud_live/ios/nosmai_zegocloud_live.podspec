Pod::Spec.new do |s|
  s.name             = 'nosmai_zegocloud_live'
  s.version          = '1.0.0'
  s.summary          = 'Livestream Nosmai-processed camera video through ZEGOCLOUD (ZEGO Express).'
  s.description      = <<-DESC
Feeds Nosmai's processed camera frames into a ZEGO Express custom video capture source,
so Flutter apps can livestream Nosmai effects without native code.
                       DESC
  s.homepage         = 'https://nosmai.com'
  s.license          = { :type => 'Proprietary', :text => 'Nosmai and the ZEGO Express SDK are governed by their own licenses.' }
  s.author           = { 'Nosmai' => 'admin@nosmai.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/NosmaiZegoLivePlugin.h'
  s.resource_bundles = {
    'nosmai_zegocloud_live_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }

  s.dependency 'Flutter'
  # The Nosmai version is pinned by nosmai_effects_sdk; keep ZEGO in step with android/build.gradle.
  s.dependency 'nosmai_effects_sdk'
  s.dependency 'ZegoExpressEngine', '3.21.0'

  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'CoreVideo', 'QuartzCore', 'UIKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
end
