#
#  Be sure to run `pod spec lint KSPhotoBrowser.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "KakaPhotoBrowser"
  s.version      = "1.0.0"
  s.summary      = "A beautiful photo browser with interactive dismissal animation."
  s.homepage     = "https://github.com/KakaPhotoBrowser"
  s.license      = "MIT"
  s.author             = { "Melo" => "MeloDreek@gmail.com" }
  s.social_media_url   = "https://kaka.com/"
  s.platform     = :ios, "11.0"
  s.source       = { :git => "https://www.kakainc.com/KakaPhotoBrowser.git", :tag => "#{s.version}" }
  s.source_files  = "KakaPhotoBrowser", "KakaPhotoBrowser/**/*.{h,m}"
  
  s.framework  = "UIKit"
  s.dependency 'SDWebImage', '~> 5.19.1'
  s.dependency 'SDWebImageFLPlugin', '~> 0.6.0'


end
