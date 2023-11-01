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


#pragma mark Finger Functions


-(bool)processFinger:(bool)isFlashOn {
    cv::Mat image_copy;
    Scalar avgPixelIntensity;
    
    // Convert the image to BGR format for processing
    cvtColor(_image, image_copy, CV_RGBA2BGR);
    
    // Calculate the average pixel intensity
    avgPixelIntensity = cv::mean(image_copy);
    
    // Formats and stores the average pixel intensities for the BGR channels into the `text` character array.
    char text[50];
    /// `sprintf` yields warnings but works fine in this .mm file
    sprintf(
            text,
            "Avg. B: %.0f, G: %.0f, R: %.0f", // Format string: displays the average intensities as whole numbers
            avgPixelIntensity.val[0],         // Blue channel average intensity value
            avgPixelIntensity.val[1],         // Green channel average intensity value
            avgPixelIntensity.val[2]          // Red channel average intensity value
    );

    // Draws the formatted text on the `_image` at a specified location with specified properties.
    cv::putText(
            _image,                         // Image on which the text will be drawn
            text,                           // The text to be drawn (average intensities)
            cv::Point(0, 25),               // Starting position (bottom-left corner) of the text. Here, (0, 25) means 0 units from the left and 25 units from the top.
            FONT_HERSHEY_PLAIN,             // Font type used to display the text
            2.0,                           // Font scale (size)
            Scalar::all(255),               // Color of the text. Here, it's white (255, 255, 255 in BGR).
            1,                             // Thickness of the lines used to draw the text
            2                              // Line type. Here, it's a line with anti-aliasing
    );

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
        // Empty the arrays
        [self.avgRedValues removeAllObjects];
        
        // Reset the index
        self.currentIndex = 0;
        redValuesPrinted = false; // Reset the flag
    // In the case that a finger has been detected...
    } else if (fingerDetected) {
        // Save the average color values
        if (self.currentIndex < self.framesCapturedThreshold) {
            // Add averaged red values to the NSArray most recent averages counting up to
            // `self.framesCapturedThreshold`
            [self.avgRedValues addObject:@(avgPixelIntensity[2])];
        } else {
            // Remove the oldest values (at index 0) from the NSArray
            [self.avgRedValues removeObjectAtIndex:0];
            
            // Add the new averaged red values to the end of the NSArray
            [self.avgRedValues addObject:@(avgPixelIntensity[2])];
        }
        
        // Update the index
        self.currentIndex++;
        
        // If we've collected 900 frames, start computing heart rate
        if (self.currentIndex >= self.framesCapturedThreshold) {
            if (!redValuesPrinted) {
                // Get the current time
                NSDate* currentTime = [NSDate date];
                // Calculate the time interval since the first time the condition was met
                NSTimeInterval timePassed = [currentTime timeIntervalSinceDate:self.messageDisplayTime];
                
                // Print each red value in the array to the console if 3 seconds have passed
                if (timePassed >= 3.0) {
                    for (NSNumber* redValue in self.avgRedValues) {
                        NSLog(@"%f", [redValue doubleValue]);
                    }
                    NSLog(@"\n\n\n\n\n\n");
                    redValuesPrinted = true; // Set the flag to prevent repeated printing
                }
            }
            
            NSInteger numberOfPeaks = [self findNumberOfPeaksInArray: self.avgRedValues];
            
            // Compute heart rate: For 30 seconds of data, heart rate in BPM would be 2 times the number of peaks
            NSInteger heartRate = numberOfPeaks * 2;
            
            self.heartrateText = [NSString stringWithFormat:@"Heart Rate: %ld BPM", (long)heartRate];

            char heartRateText[50];
            sprintf(heartRateText, "Heart Rate: %ld BPM", (long)heartRate);
            
            // Output to console
//            NSLog(@"Heart Rate: %ld BPM", (long)heartRate);
            
            // Display on screen
            cv::putText(_image, heartRateText, cv::Point(0, 40), FONT_HERSHEY_PLAIN, 2.0, Scalar::all(255), 1, 2);
            
            if (self.currentIndex == self.framesCapturedThreshold) {
                self.messageDisplayTime = [NSDate date]; // Store the current time
            }
        }
    }

    return fingerDetected;
}


-(NSInteger)findNumberOfPeaksInArray:(NSArray*)redValues {
    // Create an array for points of interest (peaks)
    NSMutableArray *poi = [NSMutableArray arrayWithCapacity:5];
    
    // Set box size
    int boxSize = 7;
    bool leftUp;
    bool rightDown;
    
    // Loop through every point
    for (int i = boxSize; i < redValues.count - boxSize; i++) {
        NSNumber* leftBox[boxSize];
        NSNumber* rightBox[boxSize];
        
        // Set up left Box with boxSize points to the left of point i
        for(int j = 0; j < boxSize; j++){
            leftBox[j] = redValues[i - j];
        }
        
        // Set up right box with boxSize points to right of point i
        for(int k = 0; k < boxSize; k++){
            rightBox[k] = redValues[i + k];
        }
        
        // Check if 0th left box element has a higher value than the edge of leftbox
        leftUp = ([leftBox[0] doubleValue] < [leftBox[boxSize - 1] doubleValue]);
        
        // Check if 0th right box element has a lower value than the edge of rightbox
        rightDown = ([rightBox[0] doubleValue] > [rightBox[boxSize - 1] doubleValue]);
        
        // If the left box tends to go up and the right box tends to go down
        if (leftUp && rightDown) {
            bool tooClose = false;
            for (int j = 0; j < poi.count; j++) {
                if (i - [poi[j] intValue] < boxSize) {
                    tooClose = true;
                    break;
                }
            }
            
            if (!tooClose) {
                [poi addObject:@(i)];
            }
        }
    }
    
    // Return the number of detected peaks (i.e., size of the poi array)
    return poi.count;
}


# pragma mark Image Functions


-(void)processImage{
    
    cv::Mat frame_gray,image_copy;
    const int kCannyLowThreshold = 150;
    const int kFilterKernelSize = 5;
    
    switch (self.processType) {
        case 1:
        {
            cvtColor( _image, frame_gray, CV_BGR2GRAY );
            bitwise_not(frame_gray, _image);
            return;
            break;
        }
        case 2:
        {
            static uint counter = 0;
            cvtColor(_image, image_copy, CV_BGRA2BGR);
            for(int i=0;i<counter;i++){
                for(int j=0;j<counter;j++){
                    uchar *pt = image_copy.ptr(i, j);
                    pt[0] = 255;
                    pt[1] = 0;
                    pt[2] = 255;
                    
                    pt[3] = 255;
                    pt[4] = 0;
                    pt[5] = 0;
                }
            }
            cvtColor(image_copy, _image, CV_BGR2BGRA);
            
            counter++;
            counter = counter>50 ? 0 : counter;
            break;
        }
        case 3:
        { // fine, adding scoping to case statements to get rid of jump errors
            // FOR FLIPPED ASSIGNMENT, YOU MAY BE INTERESTED IN THIS EXAMPLE
            char text[50];
            Scalar avgPixelIntensity;
            
            cvtColor(_image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
            avgPixelIntensity = cv::mean( image_copy );
            // they say that sprintf is depricated, but it still works for c++
            sprintf(text,"Avg. B: %.0f, G: %.0f, R: %.0f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
            cv::putText(_image, text, cv::Point(0, 20), FONT_HERSHEY_PLAIN, 2.0, Scalar::all(255), 1, 2);
            break;
        }
        case 4:
        {
            vector<Mat> layers;
            cvtColor(_image, image_copy, CV_BGRA2BGR);
            cvtColor(image_copy, image_copy, CV_BGR2HSV);
            
            //grab  just the Hue chanel
            cv::split(image_copy,layers);
            
            // shift the colors
            cv::add(layers[0],80.0,layers[0]);
            
            // get back image from separated layers
            cv::merge(layers,image_copy);
            
            cvtColor(image_copy, image_copy, CV_HSV2BGR);
            cvtColor(image_copy, _image, CV_BGR2BGRA);
            break;
        }
        case 5:
        {
            //============================================
            //threshold the image using the utsu method (optimal histogram point)
            cvtColor(_image, image_copy, COLOR_BGRA2GRAY);
            cv::threshold(image_copy, image_copy, 0, 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
            cvtColor(image_copy, _image, CV_GRAY2BGRA); //add back for display
            break;
        }
        case 6:
        {
            //============================================
            //do some blurring (filtering)
            cvtColor(_image, image_copy, CV_BGRA2BGR);
            Mat gauss = cv::getGaussianKernel(11, 9);
            cv::filter2D(image_copy, image_copy, -1, gauss);
            cvtColor(image_copy, _image, CV_BGR2BGRA);
            break;
        }
        case 7:
        {
            //============================================
            // canny edge detector
            // Convert captured frame to grayscale
            cvtColor(_image, image_copy, COLOR_BGRA2GRAY);
            
            // Perform Canny edge detection
            Canny(image_copy, _image,
                  kCannyLowThreshold,
                  kCannyLowThreshold*7,
                  kFilterKernelSize);
            
            // copy back for further processing
            cvtColor(_image, _image, CV_GRAY2BGRA); //add back for display
            break;
        }
        case 8:
        {
            //============================================
            // contour detector with rectangle bounding
            // Convert captured frame to grayscale
            vector<vector<cv::Point> > contours; // for saving the contours
            vector<cv::Vec4i> hierarchy;
            
            cvtColor(_image, frame_gray, CV_BGRA2GRAY);
            
            // Perform Canny edge detection
            Canny(frame_gray, image_copy,
                  kCannyLowThreshold,
                  kCannyLowThreshold*7,
                  kFilterKernelSize);
            
            // convert edges into connected components
            findContours( image_copy, contours, hierarchy, CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
            
            // draw boxes around contours in the original image
            for( int i = 0; i< contours.size(); i++ )
            {
                cv::Rect boundingRect = cv::boundingRect(contours[i]);
                cv::rectangle(_image, boundingRect, Scalar(255,255,255,255));
            }
            break;
            
        }
        case 9:
        {
            //============================================
            // contour detector with full bounds drawing
            // Convert captured frame to grayscale
            vector<vector<cv::Point> > contours; // for saving the contours
            vector<cv::Vec4i> hierarchy;
            
            cvtColor(_image, frame_gray, CV_BGRA2GRAY);
            
            
            // Perform Canny edge detection
            Canny(frame_gray, image_copy,
                  kCannyLowThreshold,
                  kCannyLowThreshold*7,
                  kFilterKernelSize);
            
            // convert edges into connected components
            findContours( image_copy, contours, hierarchy,
                         CV_RETR_CCOMP,
                         CV_CHAIN_APPROX_SIMPLE,
                         cv::Point(0, 0) );
            
            // draw the contours to the original image
            for( int i = 0; i< contours.size(); i++ )
            {
                Scalar color = Scalar( rand()%255, rand()%255, rand()%255, 255 );
                drawContours( _image, contours, i, color, 1, 4, hierarchy, 0, cv::Point() );
                
            }
            break;
        }
        case 10:
        {
            // Convert it to gray
            cvtColor( _image, image_copy, CV_BGRA2GRAY );
            
            // Reduce the noise
            GaussianBlur( image_copy, image_copy, cv::Size(3, 3), 2, 2 );
            
            vector<Vec3f> circles;
            
            // Apply the Hough Transform to find the circles
            HoughCircles( image_copy, circles,
                         CV_HOUGH_GRADIENT,
                         1, // downsample factor
                         image_copy.rows/20, // distance between centers
                         kCannyLowThreshold/2, // canny upper thresh
                         40, // magnitude thresh for hough param space
                         0, 0 ); // min/max centers
            
            // Draw the circles detected
            for( size_t i = 0; i < circles.size(); i++ )
            {
                cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
                int radius = cvRound(circles[i][2]);
                // circle center
                circle( _image, center, 3, Scalar(0,255,0,255), -1, 8, 0 );
                // circle outline
                circle( _image, center, radius, Scalar(0,0,255,255), 3, 8, 0 );
            }
            break;
        }
        case 11:
        {
            // example for running Haar cascades
            //============================================
            // generic Haar Cascade
            
            cvtColor(_image, image_copy, CV_BGRA2GRAY);
            vector<cv::Rect> objects;
            
            // run classifier
            // error if this is not set!
            self.classifier.detectMultiScale(image_copy, objects);
            
            // display bounding rectangles around the detected objects
            for( vector<cv::Rect>::const_iterator r = objects.begin(); r != objects.end(); r++)
            {
                cv::rectangle( _image, cvPoint( r->x, r->y ), cvPoint( r->x + r->width, r->y + r->height ), Scalar(0,0,255,255));
                
            }
            //image already in the correct color space
            break;
        }
            
        default:
            break;
            
    }
}


#pragma mark ====Do Not Manipulate Code below this line!====
-(void)setTransforms:(CGAffineTransform)trans{
    self.inverseTransform = trans;
    self.transform = CGAffineTransformInvert(trans);
}

-(void)loadHaarCascadeWithFilename:(NSString*)filename{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:filename ofType:@"xml"];
    self.classifier = cv::CascadeClassifier([filePath UTF8String]);
}

-(instancetype)init{
    self = [super init];
    
    if(self != nil){
        //self.transform = CGAffineTransformMakeRotation(M_PI_2);
        //self.transform = CGAffineTransformScale(self.transform, -1.0, 1.0);
        
        //self.inverseTransform = CGAffineTransformMakeScale(-1.0,1.0);
        //self.inverseTransform = CGAffineTransformRotate(self.inverseTransform, -M_PI_2);
        self.transform = CGAffineTransformIdentity;
        self.inverseTransform = CGAffineTransformIdentity;
        
        // Record threshold for starting to display heartbeat
        /// We are assuming that it the recording phone is 30 FPS, and we won't display until 30 seconds pass
        /// We use the formula `(time of data collected [s]) * (FPS [f/s]) = (frames captured [f])` to check if this
        /// number of frames is in the array before displaying the heartbeat values, as it would not be reliable before doing this.
        /// 30 • 30 = 900
        self.framesCapturedThreshold = 30*30;
        self.recorded30 = false;
        
        // Declare array for storing average red values into a NSMutableArray
        self.avgRedValues = [NSMutableArray arrayWithCapacity: self.framesCapturedThreshold];
        
        // Index for iterating through and checking heartbeat
        self.currentIndex = 0;
    }
    return self;
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

-(bool)getRecordedBool{
    return self.recorded30;
}




@end
