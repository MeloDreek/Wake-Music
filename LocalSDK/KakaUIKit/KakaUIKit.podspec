#
# Be sure to run `pod lib lint Categories.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "KakaUIKit"
  s.version          = "1.0.0"
  s.summary          = "KakaUIKit."
  s.homepage         = "https://www.kakainc.com/"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = "MeloDreek@gmail.com"
  s.source           = { :git => "https://www.kakainc.com//KakaUIKit.git", :tag => s.version }
  s.platform         = :ios, '14.0'
  s.requires_arc     = true
  
  #指定Pod为静态库模式
  s.static_framework = true
  s.source_files    = "Classes/**/*.swift"
  s.frameworks   = "CoreGraphics", "AudioToolbox", "QuartzCore"
  s.resources     = 'Classes/Reasource/*.{png,svg,csv,bundle}'
  
  s.dependency 'SnapKit', '~> 5.7.1'
  s.dependency 'KakaFoundation'
  s.dependency 'NVActivityIndicatorView'
  
  
end
