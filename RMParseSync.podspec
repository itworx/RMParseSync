#
# Be sure to run `pod lib lint NAME.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = "RMParseSync"
  s.version          = "0.3.3"
  s.summary          = "Offline support for Parse"
  s.description      = <<-DESC
                       Provides support for Full Offline Cashing for Parse sdk for iOS
                       DESC
  s.homepage         = "https://github.com/itworx/RMParseSync.git"
  s.license          = 'MIT'
  s.author           = { "Ramy Medhat" => "ramymedhat@gmail.com" }
  s.source           = { :git => "https://github.com/itworx/RMParseSync.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true
 
  s.source_files = 'Classes'
  
  s.xcconfig = { "FRAMEWORK_SEARCH_PATHS" => '"$(PODS_ROOT)/Parse"', "HEADER_SEARCH_PATHS" => '$(PODS_ROOT)/Parse/Parse.Framework/Versions/1.3.0/Headers"' }

  s.public_header_files = 'Classes/**/*.h', '"$(PODS_ROOT)/Parse/Parse.Framework/Versions/1.3.0/Headers"'
  s.frameworks = 'Foundation', 'CoreData'
  s.dependency 'Parse'
  s.dependency 'CocoaLumberjack'
end
