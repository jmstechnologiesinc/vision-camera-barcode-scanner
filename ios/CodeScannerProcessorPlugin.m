#import "CodeScannerProcessorPlugin.h"
#include <Foundation/Foundation.h>

static RCTEventEmitter* eventEmitter = nil;

@implementation CodeScannerProcessorPlugin

- (instancetype)initWithOptions:(NSDictionary*)options {
  self = [super init];
  return self;
}

/**
  * Frame processor callback that is called when a new frame is available.
  * 
  * @param frame The frame that is available.
  * @param arguments The arguments that were passed to the frame processor.
  */  
- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  CMSampleBufferRef buffer = frame.buffer;
  UIImageOrientation orientation = frame.orientation;

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);

  [self
      detectBarcodeInBuffer:pixelBuffer
                 completion:^(NSArray* observations) {
                   for (VNBarcodeObservation* observation in observations) {
                     NSLog(@"Payload: %@", observation.payloadStringValue);
                     NSDictionary* result =
                         [self dictionaryFromObservation:observation];
                     [result
                         setValue:[NSNumber numberWithInt:orientation]
                           forKey:@"orientation"];
                     [eventEmitter sendEventWithName:@"onBarcodeDetected"
                                                body:result];
                   }
                 }];

  return @{
    @"orientation" : [NSNumber numberWithInt:orientation]
  };
}

/**
  * Detects barcodes in the given pixel buffer and calls the completion handler
  * with the results.
  *
  * @param pixelBuffer The pixel buffer to detect barcodes in.
  * @param completion The completion handler to call with the results.
  */
- (void)detectBarcodeInBuffer:(CVPixelBufferRef)pixelBuffer
                   completion:(void (^)(NSArray*))completion {
  VNImageRequestHandler* handler =
      [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer
                                                   options:@{}];
  VNDetectBarcodesRequest* request = [[VNDetectBarcodesRequest alloc]
      initWithCompletionHandler:^(VNRequest* _Nonnull request,
                                  NSError* _Nullable error) {
        if (error) {
          NSLog(@"Error %@", error.localizedDescription);
          completion(@[]);
          return;
        }

        completion(request.results);
      }];

  NSError* error;
  [handler performRequests:@[ request ] error:&error];
  if (error) {
    NSLog(@"Error %@", error.localizedDescription);
    completion(@[]);
  }
}

/**
  * Converts a barcode observation to a dictionary representation.
  *
  * @param observation The observation to convert.
  * @return A dictionary representation of the observation.
  */
- (NSDictionary*)dictionaryFromObservation:(VNBarcodeObservation*)observation {
  NSMutableDictionary* observationRepresentation = [@{
    @"uuid" : observation.uuid.UUIDString,
    @"payload" : observation.payloadStringValue ?: [NSNull null],
    @"symbology" : observation.symbology,
    @"boundingBox" : @{
      @"origin" : @{
        @"x" : @(observation.boundingBox.origin.x),
        @"y" : @(observation.boundingBox.origin.y),
      },
      @"size" : @{
        @"width" : @(observation.boundingBox.size.width),
        @"height" : @(observation.boundingBox.size.height)
      },
    },
    @"corners" : @{
      @"topLeft" : @{
        @"x" : @(observation.topLeft.x),
        @"y" : @(observation.topLeft.y)
      },
      @"topRight" : @{
        @"x" : @(observation.topRight.x),
        @"y" : @(observation.topRight.y)
      },
      @"bottomRight" : @{
        @"x" : @(observation.bottomRight.x),
        @"y" : @(observation.bottomRight.y)
      },
      @"bottomLeft" : @{
        @"x" : @(observation.bottomLeft.x),
        @"y" : @(observation.bottomLeft.y)
      }
    },
    @"confidence" : @(observation.confidence)
  } mutableCopy];

  if (@available(iOS 14.0, *)) {
    observationRepresentation[@"timeRange"] = @{
      @"duration" : @(CMTimeGetSeconds(observation.timeRange.duration)),
      @"start" : @(CMTimeGetSeconds(observation.timeRange.start))
    };
  } else {
    // Fallback on earlier versions
  }

  return [observationRepresentation copy];
}

/**
  * Sets the event emitter that will be used to send events to the JS side.
  */
+ (void)setEventEmitter:(RCTEventEmitter*)eventEmitterArg {
  eventEmitter = eventEmitterArg;
}

/**
 * Registers this plugin with the frame processor plugin registry so that it
 * can be used.
 */
+ (void)load {
  [FrameProcessorPluginRegistry
      addFrameProcessorPlugin:@"codeScanner"
              withInitializer:^FrameProcessorPlugin*(NSDictionary* options) {
                return [[CodeScannerProcessorPlugin alloc]
                    initWithOptions:options];
              }];
}

@end
