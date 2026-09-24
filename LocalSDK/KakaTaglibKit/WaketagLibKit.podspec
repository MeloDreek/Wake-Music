Pod::Spec.new do |s|
  s.name             = 'WaketagLibKit'
  s.version          = '2.3.3'
  s.summary          = 'An Objective-C and Swift wrapper for TagLib audio metadata.'
  s.description      = 'Audio metadata, embedded artwork, and lyrics on Apple platforms, backed by TagLib 2.3.2.'
  s.homepage         = 'https://github.com/MeloDreek/WaketagLibKit'
  s.license          = { :type => 'MIT, LGPL 2.1 or MPL 1.1', :file => 'LICENSE' }
  s.author           = 'MeloDreek'
  s.source           = { :git => 'https://github.com/MeloDreek/WaketagLibKit.git', :tag => s.version.to_s }

  s.platforms        = { :ios => '15.0', :osx => '12.0', :tvos => '15.0', :watchos => '9.0' }

  s.public_header_files = ['Classes/TagLibHeader/*.h']
  s.private_header_files = 'Classes/TagLib/**/*.h'
  s.source_files = ['Classes/**/*.{h,cpp,mm}']
  s.preserve_paths = ['Classes/TagLib/**/*.tcc', 'LICENSE', 'Licenses/**/*', 'UPSTREAM.md']

  s.requires_arc = true
  s.libraries = 'c++', 'z'
  s.frameworks = 'Foundation', 'ImageIO', 'CoreGraphics'
  s.ios.frameworks = 'UIKit'
  s.osx.frameworks = 'AppKit'
  s.tvos.frameworks = 'UIKit'
  s.watchos.frameworks = 'UIKit'
  s.pod_target_xcconfig = {
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
      'CLANG_CXX_LIBRARY' => 'libc++',
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) TAGLIB_STATIC=1 HAVE_ZLIB=1',
      'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Classes/TagLib/toolkit" "$(PODS_TARGET_SRCROOT)/Classes/TagLib/thirdSDK"'
  }

end
