#source 'https://github.com/CocoaPods/Specs.git'
#source 'https://gitee.com/mirrors/CocoaPods-Specs.git'
source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'


workspace 'Wake Music.xcworkspace'
project 'Mobie/Mobie.xcodeproj'
project 'Mac/Mac.xcodeproj'


target 'Mobie' do
  project 'Mobie/Mobie.xcodeproj'

  platform :ios, '15.0'
  use_frameworks!
  inhibit_all_warnings!
  
  # 本地库
  pod 'KakaFoundation',            :path => './LocalSDK/KakaFoundation'
  pod 'KakaUIKit',                  :path => './LocalSDK/KakaUIKit'
  pod 'KakaObjcKit',                :path => './LocalSDK/KakaObjcKit'
  pod 'AppGroupKit',                :path => './LocalSDK/AppGroupKit'
  pod 'KakaPhotoBrowser',          :path => './LocalSDK/KakaPhotoBrowser'
  pod 'KakaTaglibKit',              :path => './LocalSDK/KakaTaglibKit'
  pod 'WakeMusicPlayer',            :path => './LocalSDK/WakeMusicPlayer'
# MEGASdk is linked via Xcode's local Swift package: ../../本地公开库/MEGASDK
  
  
#  pod 'Firebase'#, '~> 12.2.0'
#  pod 'Firebase/AnalyticsWithoutAdIdSupport'#, '~> 12.2.0'
#  pod 'FirebaseCrashlytics'#, '~> 12.2.0'

  
  pod 'GoogleSignIn', '~> 9.0.0'
  pod 'SwiftyDropbox', '~> 10.2.4'
  pod 'YandexLoginSDK', '~> 3.0.2'

  pod 'JXSegmentedView', '~> 1.4.1'
  pod 'ProgressHUD', '~> 14.1.1'
  
  pod 'IQKeyboardManagerSwift', '~> 8.0.3'
#  pod 'MSAL', '~> 2.4.1'
  
end


target 'Mobie_Pro' do
  project 'Mobie/Mobie.xcodeproj'

  platform :ios, '15.0'
  use_frameworks!
  inhibit_all_warnings!
  
  # 本地库
  pod 'KakaFoundation',            :path => './LocalSDK/KakaFoundation'
  pod 'KakaUIKit',                  :path => './LocalSDK/KakaUIKit'
  pod 'KakaObjcKit',                :path => './LocalSDK/KakaObjcKit'
  pod 'AppGroupKit',                :path => './LocalSDK/AppGroupKit'
  pod 'KakaPhotoBrowser',          :path => './LocalSDK/KakaPhotoBrowser'
  pod 'KakaTaglibKit',              :path => './LocalSDK/KakaTaglibKit'
  pod 'WakeMusicPlayer',            :path => './LocalSDK/WakeMusicPlayer'
# MEGASdk is linked via Xcode's local Swift package: ../../本地公开库/MEGASDK

  
#  pod 'Firebase'#, '~> 12.2.0'
#  pod 'Firebase/AnalyticsWithoutAdIdSupport'#, '~> 12.2.0'
#  pod 'FirebaseCrashlytics'#, '~> 12.2.0'
  
  
  pod 'GoogleSignIn', '~> 9.0.0'
  pod 'SwiftyDropbox', '~> 10.2.4'
  pod 'YandexLoginSDK', '~> 3.0.2'
  
  pod 'JXSegmentedView', '~> 1.4.1'
  pod 'ProgressHUD', '~> 14.1.1'
  
  pod 'IQKeyboardManagerSwift', '~> 8.0.3'
#  pod 'MSAL', '~> 2.4.1'

  
end



post_install do |installer|
  # CocoaPods generates quoted umbrella-header imports that Xcode 27's module
  # verifier rejects. These are app dependencies, not independently distributed
  # frameworks; keep normal module compilation, but skip this packaging check.
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'
      # 为 iOS 目标设置最低部署版本
      if target.platform_name == :ios
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # 为 macOS 目标设置最低部署版本
      elsif target.platform_name == :osx
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
      end
    end
  end
end
