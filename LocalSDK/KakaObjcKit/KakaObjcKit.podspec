#
#  Be sure to run `pod spec lint KakaObjcKit.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name             = "KakaObjcKit"
  s.version          = "1.0.0"
  s.summary          = "KakaObjcKit."
  s.homepage         = "https://www.kakainc.com/"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = "MeloDreek@gmail.com"
  s.source           = { :git => "https://www.kakainc.com/KakaObjcKit.git", :tag => s.version }
  s.platform         = :ios, '14.0'
  s.requires_arc     = true
  
  #指定Pod为静态库模式
  s.static_framework = true
  s.public_header_files = "Classes/**/*.h"
  s.source_files    = "Classes/**/*.{h,m}"
  s.frameworks   = "UIKit", "Foundation", "CoreLocation", "Security"

end
