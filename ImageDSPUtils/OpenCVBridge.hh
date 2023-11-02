//
//  OpenCVBridge.h
//  LookinLive
//
//  Created by Eric Larson.
//  Copyright (c) Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import "AVFoundation/AVFoundation.h"

#import "PrefixHeader.pch"

@interface OpenCVBridge : NSObject

@property (nonatomic) NSInteger processType;
@property (nonatomic) size_t framesCapturedThreshold;  // FRAME THRESHOLD FOR DISPLAYING HEARTBEAT VALUES
@property (nonatomic, strong) NSMutableArray *avgRedValues;   // PAST 100 AVERAGE R VALUES
@property (nonatomic) int currentIndex;  // LOCATION TO REPLACE OR ADD BGR AVERAGES
@property (nonatomic, strong) NSString *heartrateText;


// set the image for processing later
-(void) setImage:(CIImage*)ciFrameImage
      withBounds:(CGRect)rect
      andContext:(CIContext*)context;

//get the image raw opencv
-(CIImage*)getImage;

//get the image inside the original bounds
-(CIImage*)getImageComposite;

// call this to perform finger-on-camera processing (user controlled for better transparency)
-(bool)processFinger:(BOOL)isFlashOn;

// helper function inside `processFinger()` to store reach red value for each frame and cycle
// previously collected values back by one
-(void)cycleRedValuesWithNewValue:(NSNumber*)newValue;

// call this inside of `processFinger()` to retrieve the number of peaks in the red channel array
-(NSInteger)findNumberOfPeaksInArray:(NSArray*)array;

// For retireving the heartrate recorded of the finger
-(NSString*)getHeartrateText;

// Function for drawing box on image when it is called, which happens when a face appears
-(void)drawBoxX:(float)x1 toY:(float)y1 andX:(float)x2 andY:(float)y2;

@end
