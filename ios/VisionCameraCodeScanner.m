#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import "CodeScannerProcessorPlugin.h"
#import "VisionCameraCodeScanner.h"

@implementation VisionCameraCodeScanner {
  bool hasListeners;
}

RCT_EXPORT_MODULE();

- (instancetype)init;
{
  self = [super init];
  if (self) {
    // Publish ourselves as an RCTEventEmitter on the frame processor plugin
    [CodeScannerProcessorPlugin setEventEmitter:self];
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[ @"onBarcodeDetected" ];
}

- (void)startObserving {
  hasListeners = YES;
}

- (void)stopObserving {
  hasListeners = NO;
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

@end
