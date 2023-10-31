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
@property (nonatomic, strong) NSDate *messageDisplayTime;     // TIME WHICH LAST 100 VALUES ARE READ
@property (nonatomic, strong) NSDate *lastMessageDisplayTime;


// set the image for processing later
-(void) setImage:(CIImage*)ciFrameImage
      withBounds:(CGRect)rect
      andContext:(CIContext*)context;

//get the image raw opencv
-(CIImage*)getImage;

//get the image inside the original bounds
-(CIImage*)getImageComposite;

// call this to perfrom processing (user controlled for better transparency)
-(void)processImage;

// call this to perform finger-on-camera processing (user controlled for better transparency)
-(bool)processFinger:(BOOL)isFlashOn;

// for the video manager transformations
-(void)setTransforms:(CGAffineTransform)trans;

-(void)loadHaarCascadeWithFilename:(NSString*)filename;

@end
