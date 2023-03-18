platform :ios, '12.0'
use_frameworks!
inhibit_all_warnings!

def install_all
  pod 'Firebase/Crashlytics', '~> 6.27.0'
  pod 'Firebase/Messaging', '~> 6.27.0'
  pod 'MBProgressHUD', '~> 1.1.0'
  pod 'TMReachability', :git => 'https://github.com/albertbori/Reachability'
  pod 'Natrium', '~> 8.0.0'
  pod 'CrossroadRegex', '~> 1.1.0'
  pod 'SwiftyBeaver', '~> 1.5.1'
  pod 'SimulatorStatusMagic', :configurations => ['Debug']
  pod 'NVActivityIndicatorView', '4.8.0'
  pod 'GoogleSignIn', '~> 4.1.2'
  pod 'FacebookCore', '~> 0.9.0'
  pod 'FacebookLogin', '~> 0.9.0'
end

target 'PartiApp Debug' do
  install_all
end

target 'PartiApp Release' do
  install_all
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    puts target.name
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '4.0'
      if config.name != 'Release'
        config.build_settings["VALID_ARCHS[sdk=iphonesimulator*]"] = "arm64, arm64e, armv7, armv6, i386, x86_64"
      end
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
