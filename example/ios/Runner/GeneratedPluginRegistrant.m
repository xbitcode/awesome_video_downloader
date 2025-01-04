//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<awesome_video_downloader/AwesomeVideoDownloaderPlugin.h>)
#import <awesome_video_downloader/AwesomeVideoDownloaderPlugin.h>
#else
@import awesome_video_downloader;
#endif

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AwesomeVideoDownloaderPlugin registerWithRegistrar:[registry registrarForPlugin:@"AwesomeVideoDownloaderPlugin"]];
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
}

@end
