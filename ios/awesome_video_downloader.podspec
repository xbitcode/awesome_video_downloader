Pod::Spec.new do |s|
  s.name             = 'awesome_video_downloader'
  s.version          = '0.1.7'
  s.summary          = 'A Flutter plugin for downloading videos in various formats'
  s.description      = <<-DESC
A Flutter plugin for downloading videos in various formats (HLS, DASH, MP4) with support for background downloads, progress tracking, and offline playback.
                       DESC
  s.homepage         = 'https://github.com/AkmaljonAbdirakhimov/awesome_video_downloader'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Akmaljon Abdirakhimov' => 'akmaljondev@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end