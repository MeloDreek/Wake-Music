#
# Be sure to run `pod lib lint KakaTaglibKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'KakaTaglibKit'
  s.version          = '2.0.2'
  s.summary          = 'KakaTaglibKit is a wrapper for the TagLib Audio Meta-Data Library.'
  s.description      = 'KakaTaglibKit Audio Meta-Data Library'
  s.homepage         = 'https://github.com/lemonhead94/KakaTaglibKit'
  s.license          = { :type => 'LGPL and MPL', :file => 'LICENSE' }
  s.author           = { 'lemonhead94' => 'jorit.studer@gmail.com' }
  s.source           = { :git => 'https://github.com/lemonhead94/KakaTaglibKit.git', :tag => s.version.to_s }

  s.platforms        = { :ios => '14.0', :osx => '11.0' }

  s.public_header_files = ['Classes/TagLibHeader/*.h']
  s.private_header_files = 'Classes/TagLib/**/*.h'
  s.source_files = ['Classes/**/**/*.{h,cpp,mm}']

  s.library = 'c++'
  s.xcconfig = {
      'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
      'CLANG_CXX_LIBRARY' => 'libc++'
  }
  
end
