#
# Be sure to run `pod lib lint Categories.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "WakeMusicPlayer"
  s.version          = "1.0.0"
  s.summary          = "WakeMusicPlayer."
  s.homepage         = "https://www.kakainc.com/"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = "MeloDreek@gmail.com"
  s.source           = { :git => "https://www.kakainc.com/WakeMusicPlayer.git", :tag => s.version }
  s.platforms        = { :ios => '14.0', :osx => '10.15' }
  s.requires_arc     = true
  
  #指定Pod为静态库模式
  s.static_framework = false
  s.source_files    = "Classes/**/*.swift"
  s.frameworks      = "AVFoundation"
  
end
