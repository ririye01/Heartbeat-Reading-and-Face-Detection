//
//  OpenCVBridge.m
//  LookinLive
//
//  Created by Eric Larson.
//  Copyright (c) Eric Larson. All rights reserved.
//

#import "OpenCVBridge.hh"


using namespace cv;

@interface OpenCVBridge()
@property (nonatomic) cv::Mat image;
@property (strong,nonatomic) CIImage* frameInput;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CGAffineTransform inverseTransform;
@property (atomic) cv::CascadeClassifier classifier;
@end

@implementation OpenCVBridge

# pragma mark Init

-(instancetype)init{
    self = [super init];
    
    if(self != nil){
        self.transform = CGAffineTransformIdentity;
        self.inverseTransform = CGAffineTransformIdentity;
        
        // Record threshold for starting to display heartbeat
        /// We are assuming that it the recording phone is 30 FPS, and we won't display until 30 seconds pass
        /// We use the formula `(time of data collected [s]) * (FPS [f/s]) = (frames captured [f])` to check if this
        /// number of frames is in the array before displaying the heartbeat values, as it would not be reliable before doing this.
        /// 30 • 30 = 900
        self.framesCapturedThreshold = 30*30;
        
        // Declare array for storing average red values into a NSMutableArray
        /// Initialize avgRedValues with zeros to start
        self.avgRedValues = [[NSMutableArray alloc] initWithCapacity:self.framesCapturedThreshold];
        for (NSInteger i = 0; i < self.framesCapturedThreshold; i++) {
            [self.avgRedValues addObject:@(0)];
        }
        
        // Index for iterating through and checking heartbeat
        self.currentIndex = 0;
    }
    return self;
}


#pragma mark Finger Functions


-(bool)processFinger:(bool)isFlashOn {
    // Initialize the image and pixel intensity variables
    cv::Mat image_copy;
    Scalar avgPixelIntensity;
    
    // Convert the image to BGR format for processing
    cvtColor(_image, image_copy, CV_RGBA2BGR);
    
    // Calculate the average pixel intensity
    avgPixelIntensity = cv::mean(image_copy);
    
    // Check conditions based on flash status and average pixel intensities
    /// Turn on the flash if a finger appears in front of the camera, causing BGR values to scale to where we think
    /// they'd be
    bool fingerDetected = false;
    if (!isFlashOn && avgPixelIntensity[0] < 20 && avgPixelIntensity[1] < 20 && avgPixelIntensity[2] > 22) {
        fingerDetected = true;
    } else if (isFlashOn && avgPixelIntensity[0] < 50 && avgPixelIntensity[1] < 50 && avgPixelIntensity[2] > 100) {
        fingerDetected = true;
    }
    
    bool redValuesPrinted = false;
    
    // If a finger was previously detected but is no longer detected...
    if (!fingerDetected && isFlashOn) {
        // Refill the array with zeroes instead of removing all objects
        for (NSInteger i = self.framesCapturedThreshold; i <= 0; --i) {
            self.avgRedValues[i] = @(0);
        } 
        
        // Reset the index
        self.currentIndex = 0;
        redValuesPrinted = false; // Reset the flag
        
    // In the case that a finger has been detected...
    } else if (fingerDetected) {
        // Cycle in the new value by invoking the helper function
        [self cycleRedValuesWithNewValue:@(avgPixelIntensity[2])];
        
        // Update the index
        self.currentIndex++;
        
        // If we've collected 900 frames, start computing heart rate
        if (self.currentIndex >= self.framesCapturedThreshold) {
            //calls peak finding function
            NSInteger numberOfPeaks = [self findNumberOfPeaksInArray: self.avgRedValues];
            
            // Compute heart rate: For 30 seconds of data, heart rate in BPM would be 2 times the number of peaks
            NSInteger heartRate = numberOfPeaks * 2;
            
            // Adjust heart rate text value
            self.heartrateText = [NSString stringWithFormat:@"Heart Rate: %ld BPM", (long)heartRate];
        }
    }

    return fingerDetected;
}

- (void)cycleRedValuesWithNewValue:(NSNumber *)newValue {
    // Shift values to the left
    for (NSInteger i = 0; i < self.framesCapturedThreshold - 1; i++) {
        self.avgRedValues[i] = self.avgRedValues[i + 1];
    }
    // Insert the new value at the end
    self.avgRedValues[self.framesCapturedThreshold - 1] = newValue;
}


-(NSInteger)findNumberOfPeaksInArray:(NSArray*)redValues {
    // Create an array for points of interest (peaks)
    NSMutableArray *poi = [NSMutableArray arrayWithCapacity:5];
    
    // Set box size
    int boxSizeRight = 3;
    int boxSizeLeft = 3;
    bool leftUp;
    bool rightDown;
    
    // Loop through every point
    // DO NOT INCLUDE AN i++ BECAUSE WE MANUALLY ITERATE AT A VALUE FOR IF A PEAK IS DETECTED OR NOT
    for (int i = boxSizeLeft; i < redValues.count - boxSizeLeft;) {
        NSNumber* leftBox[boxSizeLeft];
        NSNumber* rightBox[boxSizeRight];
        
        // Set up left Box with boxSize points to the left of point i
        for(int j = 0; j < boxSizeLeft; j++){
            leftBox[j] = redValues[i - j];
        }
        
        // Set up right box with boxSize points to right of point i
        for(int k = 0; k < boxSizeRight; k++){
            rightBox[k] = redValues[i + k];
        }
        
        // Check if 0th left box element has a lower value than the edge of leftbox
        leftUp = ([leftBox[0] doubleValue] < [leftBox[boxSizeLeft - 1] doubleValue]);
        // Check if 0th right box element has a higher value than the edge of rightbox
        rightDown = ([rightBox[0] doubleValue] > [rightBox[boxSizeRight - 1] doubleValue]);
        
        
        // If the left box tends to go up and the right box tends to go down
        if (leftUp && rightDown) {
            bool tooClose = false;
            for (int j = 0; j < poi.count; j++) {
                //if it is too close to last peak, ignore
                if (i - [poi[j] intValue] < boxSizeLeft) {
                    tooClose = true;
                    break;
                }
            }
            
            // Shift 12 values to the right if it is a poi
            if (!tooClose) {
                [poi addObject:@(i)];
                i = i + 12;
            }
        }
        else{
            //go to next point
            i++;
        }
    }
    
    

    
    // Return the number of detected peaks (i.e., size of the poi array)
    return poi.count;
}


# pragma mark Image Functions

// Function for drawing box on the current image
// Takes in four floats in this order: Top left x, top left y, bottom left x, bottom left y
-(void)drawBoxX:(float)x1 toY:(float)y1 andX:(float)x2 andY:(float)y2{
    cv::Point pt1(x1, y1); // Create top left point
    cv::Point pt2(x2, y2); // Create bottom right point
    cv::rectangle(_image, pt1, pt2, cv::Scalar(0, 0, 0), -1); // Draw rectangle from point 1 to point 2, filled black
}

#pragma mark Bridging OpenCV/CI Functions
// code manipulated from
// http://stackoverflow.com/questions/30867351/best-way-to-create-a-mat-from-a-ciimage
// http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c


-(void) setImage:(CIImage*)ciFrameImage
      withBounds:(CGRect)faceRectIn
      andContext:(CIContext*)context{
    
    CGRect faceRect = CGRect(faceRectIn);
    faceRect = CGRectApplyAffineTransform(faceRect, self.transform);
    ciFrameImage = [ciFrameImage imageByApplyingTransform:self.transform];
    
    
    //get face bounds and copy over smaller face image as CIImage
    //CGRect faceRect = faceFeature.bounds;
    _frameInput = ciFrameImage; // save this for later
    _bounds = faceRect;
    CIImage *faceImage = [ciFrameImage imageByCroppingToRect:faceRect];
    CGImageRef faceImageCG = [context createCGImage:faceImage fromRect:faceRect];
    
    // setup the OPenCV mat fro copying into
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(faceImageCG);
    CGFloat cols = faceRect.size.width;
    CGFloat rows = faceRect.size.height;
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    _image = cvMat;
    
    // setup the copy buffer (to copy from the GPU)
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                      // Height of bitmap
                                                    8,                         // Bits per component
                                                    cvMat.step[0],             // Bytes per row
                                                    colorSpace,                // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    //kCGImageAlphaLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    // do the copy
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), faceImageCG);
    
    // release intermediary buffer objects
    CGContextRelease(contextRef);
    CGImageRelease(faceImageCG);
    
}

-(CIImage*)getImage{
    
    // convert back
    // setup NS byte buffer using the data from the cvMat to show
    NSData *data = [NSData dataWithBytes:_image.data
                                  length:_image.elemSize() * _image.total()];
    
    CGColorSpaceRef colorSpace;
    if (_image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    // setup buffering object
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // setup the copy to go from CPU to GPU
    CGImageRef imageRef = CGImageCreate(_image.cols,                                     // Width
                                        _image.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * _image.elemSize(),                           // Bits per pixel
                                        _image.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        //kCGImageAlphaLast |
                                        kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    // do the copy inside of the object instantiation for retImage
    CIImage* retImage = [[CIImage alloc]initWithCGImage:imageRef];
    CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.origin.x, self.bounds.origin.y);
    retImage = [retImage imageByApplyingTransform:transform];
    retImage = [retImage imageByApplyingTransform:self.inverseTransform];
    
    // clean up
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return retImage;
}

-(CIImage*)getImageComposite{
    
    // convert back
    // setup NS byte buffer using the data from the cvMat to show
    NSData *data = [NSData dataWithBytes:_image.data
                                  length:_image.elemSize() * _image.total()];
    
    CGColorSpaceRef colorSpace;
    if (_image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    // setup buffering object
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // setup the copy to go from CPU to GPU
    CGImageRef imageRef = CGImageCreate(_image.cols,                                     // Width
                                        _image.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * _image.elemSize(),                           // Bits per pixel
                                        _image.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        //kCGImageAlphaLast |
                                        kCGImageAlphaNoneSkipLast,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    // do the copy inside of the object instantiation for retImage
    CIImage* retImage = [[CIImage alloc]initWithCGImage:imageRef];
    // now apply transforms to get what the original image would be inside the Core Image frame
    CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.origin.x, self.bounds.origin.y);
    retImage = [retImage imageByApplyingTransform:transform];
    CIFilter* filt = [CIFilter filterWithName:@"CISourceAtopCompositing"
                          withInputParameters:@{@"inputImage":retImage,@"inputBackgroundImage":self.frameInput}];
    retImage = filt.outputImage;
    
    // clean up
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    retImage = [retImage imageByApplyingTransform:self.inverseTransform];
    
    return retImage;
}

-(NSString*)getHeartrateText{
    return self.heartrateText;
}

@end
