#import "MicNoiseLevelPlugin.h"
#if __has_include(<mic_noise_level/mic_noise_level-Swift.h>)
#import <mic_noise_level/mic_noise_level-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mic_noise_level-Swift.h"
#endif

@implementation MicNoiseLevelPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMicNoiseLevelPlugin registerWithRegistrar:registrar];
}
@end
