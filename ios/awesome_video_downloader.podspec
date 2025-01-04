Pod::Spec.new do |s|
  s.name             = 'awesome_video_downloader'
  s.version          = '0.0.1'
  s.summary          = 'A video downloader plugin for Flutter'
  s.description      = <<-DESC
A Flutter plugin for downloading videos in various formats (HLS, DASH, MP4) with support for background downloads.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end 