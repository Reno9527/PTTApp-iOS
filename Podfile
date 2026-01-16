# Podfile for PTT 互联
platform :ios, '15.0'
use_frameworks!

target 'PTTApp' do
  # 暂无第三方依赖（已移除高德地图 SDK，改用苹果地图）
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
