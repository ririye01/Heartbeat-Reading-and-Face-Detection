//
//  VideoAnalgesic.swift
//  VideoAnalgesicTest
//
//  Created by Eric Larson on 2015.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

import Foundation
import GLKit
import AVFoundation
import CoreImage


typealias ProcessBlock = (_ imageInput : CIImage ) -> (CIImage)

class VideoAnalgesic: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    private var captureSessionQueue: DispatchQueue //dispatch_queue_t
    private var devicePosition: AVCaptureDevice.Position
    private var window:UIWindow??
    var videoPreviewView:GLKView
    var ciOrientation = 1
    private var _eaglContext:EAGLContext!
    private var ciContext:CIContext!
    private var videoPreviewViewBounds:CGRect = CGRect.zero
    private var processBlock:ProcessBlock? = nil
    private var videoDevice: AVCaptureDevice? = nil
    private var captureSession:AVCaptureSession? = nil
    private var preset:String? = AVCaptureSession.Preset.medium.rawValue
    private var captureOrient:AVCaptureVideoOrientation? = nil
    private var _isRunning:Bool = false
    var transform : CGAffineTransform = CGAffineTransform.identity
    
    var isRunning:Bool {
        get {
            return self._isRunning
        }
    }
    
    // singleton method
    class var sharedInstance: VideoAnalgesic {
        
        struct Static {
            static let instance: VideoAnalgesic = VideoAnalgesic()
        }
        return Static.instance
    }
    
    // for setting the filters pipeline (r whatever processing you are doing)
    func setProcessingBlock(newProcessBlock: @escaping ProcessBlock)
    {
        self.processBlock = newProcessBlock // to find out: does Swift do a deep copy??
    }
    
    // for setting the camera we should use
    func setCameraPosition(position: AVCaptureDevice.Position){
        // AVCaptureDevicePosition.Back
        // AVCaptureDevicePosition.Front
        if(position != self.devicePosition){
            self.devicePosition = position;
            if(self.isRunning){
                self.stop()
                self.start()
            }
        }
    }
    
    // for setting the camera we should use
    func toggleCameraPosition(){
        // AVCaptureDevicePosition.Back
        // AVCaptureDevicePosition.Front
        switch self.devicePosition{
        case AVCaptureDevice.Position.back:
            self.devicePosition = AVCaptureDevice.Position.front
        case AVCaptureDevice.Position.front:
            self.devicePosition = AVCaptureDevice.Position.back
        default:
            self.devicePosition = AVCaptureDevice.Position.front
        }
        
        if(self.isRunning){
            self.stop()
            self.start()
        }
    }
    
    // for setting the image quality
    func setPreset(_ preset: String){
        // AVCaptureSessionPresetPhoto
        // AVCaptureSessionPresetHigh
        // AVCaptureSessionPresetMedium <- default
        // AVCaptureSessionPresetLow
        // AVCaptureSessionPreset320x240
        // AVCaptureSessionPreset352x288
        // AVCaptureSessionPreset640x480
        // AVCaptureSessionPreset960x540
        // AVCaptureSessionPreset1280x720
        // AVCaptureSessionPresetiFrame960x540
        // AVCaptureSessionPresetiFrame1280x720
        if(preset != self.preset){
            self.preset = preset;
            if(self.isRunning){
                self.stop()
                self.start()
            }
        }
    }
    
    func getCIContext()->(CIContext?){
        if let context = self.ciContext{
            return context;
        }
        return nil;
    }
    
    func getImageOrientationFromUIOrientation(_ interfaceOrientation:UIInterfaceOrientation)->(Int){
        var ciOrientation = 1;
        
        switch interfaceOrientation{
        case UIInterfaceOrientation.portrait:
            ciOrientation = 5
        case UIInterfaceOrientation.portraitUpsideDown:
            ciOrientation = 7
        case UIInterfaceOrientation.landscapeLeft:
            ciOrientation = 1
        case UIInterfaceOrientation.landscapeRight:
            ciOrientation = 3
        default:
            ciOrientation = 1
        }
        
        return ciOrientation
    }
    
    func shutdown(){
        EAGLContext.setCurrent(self._eaglContext)
        self.processBlock = nil
        self.stop()
    }
    
    override init() {
        
        // create a serial queue
        captureSessionQueue = DispatchQueue(label: "capture_session_queue")
        devicePosition = AVCaptureDevice.Position.back
        self.window = UIApplication.shared.delegate?.window
        
        _eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES3)
        if _eaglContext==nil{
            NSLog("Attempting to fall back on OpenGL 2.0")
            _eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2)
        }
        transform = CGAffineTransform.identity
        if _eaglContext != nil{
            videoPreviewView = GLKView(frame: window!!.bounds, context: _eaglContext)
            videoPreviewView.enableSetNeedsDisplay = false
            
            // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
            
            transform = transform.rotated(by: CGFloat(Double.pi/2))
            //transform = CGAffineTransformRotate(transform, CGFloat(M_PI_2))
            if devicePosition == AVCaptureDevice.Position.front{
                transform = transform.concatenating(CGAffineTransform(scaleX: -1.0, y: 1.0))
            }
            videoPreviewView.transform = transform
            videoPreviewView.frame = window!!.bounds
            
            // we make our video preview view a subview of the window, and send it to the back; this makes FHViewController's view (and its UI elements) on top of the video preview, and also makes video preview unaffected by device rotation
            window!!.addSubview(videoPreviewView)
            window!!.sendSubview(toBack: videoPreviewView)
            
            
            // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
            ciContext = CIContext(eaglContext: _eaglContext)
            
            // bind the frame buffer to get the frame buffer width and height;
            // the bounds used by CIContext when drawing to a GLKView are in pixels (not points),
            // hence the need to read from the frame buffer's width and height;
            // in addition, since we will be accessing the bounds in another queue (_captureSessionQueue),
            // we want to obtain this piece of information so that we won't be
            // accessing _videoPreviewView's properties from another thread/queue
            videoPreviewView.bindDrawable()
            videoPreviewViewBounds = CGRect.zero
        }
        else{
            NSLog("Could not fall back on OpenGL 2.0, exiting")
            videoPreviewView = GLKView()
            videoPreviewViewBounds = CGRect.zero
        }
        
        
        super.init()
        
        
    }
    
    private func start_internal()->(){
        
        if (captureSession != nil){
            return; // we are already running, just return
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(VideoAnalgesic.updateOrientation),
                                               name:NSNotification.Name(rawValue: "UIApplicationDidChangeStatusBarOrientationNotification"),
                                               object:nil)
        
        captureSessionQueue.async(){
            let error:Error? = nil;
            let position = self.devicePosition;
            self.videoDevice = nil;
            
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                               mediaType: AVMediaType.video,
                                                                               position: AVCaptureDevice.Position.unspecified)
            
            for device in deviceDiscoverySession.devices {
                if device.position == position {
                    self.videoDevice = device
                    break;
                }
            }
            
            
            // get the input device and also validate the settings
            //            let videoDevices = AVCaptureDevice.devices(for: AVMediaType.video)
            //
            //            for device in videoDevices {
            //                if (device.position == position) {
            //                    self.videoDevice = device as? AVCaptureDevice
            //                    break;
            //                }
            //            }
            
            // obtain device input
            let videoDeviceInput: AVCaptureDeviceInput = (try! AVCaptureDeviceInput(device: self.videoDevice!))
            
            if (error != nil)
            {
                NSLog("Unable to obtain video device input, error: \(String(describing: error))");
                return;
            }
            
            
            if (self.videoDevice?.supportsSessionPreset(AVCaptureSession.Preset(rawValue: self.preset!))==false)
            {
                NSLog("Capture session preset not supported by video device: \(String(describing: self.preset))");
                return;
            }
            
            // CoreImage wants BGRA pixel format
            //var outputSettings = [kCVPixelBufferPixelFormatTypeKey:NSNumber.numberWithInteger(kCVPixelFormatType_32BGRA)]
            
            // create the capture session
            self.captureSession = AVCaptureSession()
            self.captureSession!.sessionPreset = AVCaptureSession.Preset(rawValue: self.preset!);
            
            // create and configure video data output
            let videoDataOutput = AVCaptureVideoDataOutput()
            //videoDataOutput.videoSettings = outputSettings;
            videoDataOutput.alwaysDiscardsLateVideoFrames = true;
            videoDataOutput.setSampleBufferDelegate(self, queue:self.captureSessionQueue)
            
            // begin configure capture session
            if let capture = self.captureSession{
                capture.beginConfiguration()
                
                if (!capture.canAddOutput(videoDataOutput))
                {
                    return;
                }
                
                // connect the video device input and video data and still image outputs
                capture.addInput(videoDeviceInput as AVCaptureInput)
                capture.addOutput(videoDataOutput)
                
                capture.commitConfiguration()
                
                // then start everything
                capture.startRunning()
            }
            
            self.updateOrientation()
        }
    }
    
    @objc func updateOrientation(){
        if !self._isRunning{
            return
        }
        
        DispatchQueue.main.async(){
            
            switch (UIDevice.current.orientation, self.videoDevice!.position){
            case (UIDeviceOrientation.landscapeRight, AVCaptureDevice.Position.back):
                self.ciOrientation = 3
                self.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
            case (UIDeviceOrientation.landscapeLeft, AVCaptureDevice.Position.back):
                self.ciOrientation = 1
                self.transform = CGAffineTransform.identity
            case (UIDeviceOrientation.landscapeLeft, AVCaptureDevice.Position.front):
                self.ciOrientation = 3
                self.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                self.transform = self.transform.concatenating(CGAffineTransform(scaleX: -1.0, y: 1.0))
            case (UIDeviceOrientation.landscapeRight, AVCaptureDevice.Position.front):
                self.ciOrientation = 1
                self.transform = CGAffineTransform.identity
                self.transform = self.transform.concatenating(CGAffineTransform(scaleX: -1.0, y: 1.0))
            case (UIDeviceOrientation.portraitUpsideDown, AVCaptureDevice.Position.back):
                self.ciOrientation = 7
                self.transform = CGAffineTransform(rotationAngle: CGFloat(3*Double.pi/2))
            case (UIDeviceOrientation.portraitUpsideDown, AVCaptureDevice.Position.front):
                self.ciOrientation = 7
                self.transform = CGAffineTransform(rotationAngle: CGFloat(3*Double.pi/2))
                self.transform = self.transform.concatenating(CGAffineTransform(scaleX: -1.0, y: 1.0))
            case (UIDeviceOrientation.portrait, AVCaptureDevice.Position.back):
                self.ciOrientation = 5
                self.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
            case (UIDeviceOrientation.portrait, AVCaptureDevice.Position.front):
                self.ciOrientation = 5
                self.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
                self.transform = self.transform.concatenating(CGAffineTransform(scaleX: -1.0, y: -1.0))
            default:
                self.ciOrientation = 5
                self.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
            }
            
            self.videoPreviewView.transform = self.transform
            self.videoPreviewView.frame = self.window!!.bounds
        }
    }
    
    func start(){
        
        self.videoPreviewViewBounds.size.width = CGFloat(self.videoPreviewView.drawableWidth)
        self.videoPreviewViewBounds.size.height = CGFloat(self.videoPreviewView.drawableHeight)
        
        
        // see if we have any video device
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                           mediaType: AVMediaType.video,
                                                                           position: AVCaptureDevice.Position.unspecified)
        
        if (deviceDiscoverySession.devices.count > 0)
        {
            self.start_internal()
            self._isRunning = true
        }
        else{
            NSLog("Could not start Analgesic video manager");
            NSLog("Be sure that you are running from an iOS device, not the simulator")
            self._isRunning = false;
        }
        
    }
    
    func stop(){
        if (self.captureSession==nil || self.captureSession!.isRunning==false){
            return
        }
        
        self.captureSession!.stopRunning()
        
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: "UIApplicationDidChangeStatusBarOrientationNotification"), object: nil)
        
        self.captureSessionQueue.sync(){
            NSLog("waiting for capture session to end")
        }
        NSLog("Done!")
        
        self.captureSession = nil
        self.videoDevice = nil
        self._isRunning = false
        
    }
    
    // video buffer delegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceImage = CIImage(cvPixelBuffer: imageBuffer! as CVPixelBuffer, options:nil)
        
        // run through a filter
        var filteredImage:CIImage! = nil;
        
        if(self.processBlock != nil){
            filteredImage=self.processBlock!(sourceImage)
        }
        
        let sourceExtent:CGRect = sourceImage.extent
        
        let sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
        let previewAspect = self.videoPreviewViewBounds.size.width  / self.videoPreviewViewBounds.size.height;
        
        // we want to maintain the aspect ratio of the screen size, so we clip the video image
        var drawRect = sourceExtent
        if (sourceAspect > previewAspect)
        {
            // use full height of the video image, and center crop the width
            drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
            drawRect.size.width = drawRect.size.height * previewAspect;
        }
        else
        {
            // use full width of the video image, and center crop the height
            drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
            drawRect.size.height = drawRect.size.width / previewAspect;
        }
        
        if (filteredImage != nil)
        {
            DispatchQueue.main.async(){
                
                self.videoPreviewView.bindDrawable()
                
                if (self._eaglContext != EAGLContext.current()){
                    EAGLContext.setCurrent(self._eaglContext)
                }
                
                // clear eagl view to grey
                glClearColor(0.5, 0.5, 0.5, 1.0);
                glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                
                // set the blend mode to "source over" so that CI will use that
                glEnable(GLenum(GL_BLEND))
                glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
                
                
                if (filteredImage != nil){
                    self.ciContext.draw(filteredImage, in:self.videoPreviewViewBounds, from:drawRect)
                }
                
                self.videoPreviewView.display()
            }
        }
        
    }
    
    func toggleFlash()->(Bool){
        var isOn = false
        if let device = self.videoDevice{
            if (device.hasTorch && self.devicePosition == AVCaptureDevice.Position.back) {
                do {
                    try device.lockForConfiguration()
                } catch _ {
                }
                if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                    device.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    do {
                        try device.setTorchModeOn(level: 1.0)
                        isOn = true
                    } catch _ {
                        isOn = false
                    }
                }
                device.unlockForConfiguration()
            }
        }
        return isOn
    }
    
    func setFPS(desiredFrameRate:Double){
        if let device = self.videoDevice{
            do {
                try device.lockForConfiguration()
            } catch _ {
            }
            
            // set to 120FPS
            let format = device.activeFormat
            let time:CMTime = CMTimeMake(1, Int32(desiredFrameRate))
            
            for range in format.videoSupportedFrameRateRanges {
                if range.minFrameRate <= (desiredFrameRate + 0.0001) && range.maxFrameRate >= (desiredFrameRate - 0.0001) {
                    device.activeVideoMaxFrameDuration = time
                    device.activeVideoMinFrameDuration = time
                    print("Changed FPS to \(desiredFrameRate)")
                    break
                }
                
            }
            device.unlockForConfiguration()
        }
        
        
    }
    
    
    func turnOnFlashwithLevel(_ level:Float) -> (Bool){
        var isOverHeating = false
        if let device = self.videoDevice{
            if (device.hasTorch && self.devicePosition == AVCaptureDevice.Position.back && level>0 && level<=1) {
                do {
                    try device.lockForConfiguration()
                } catch _ {
                }
                do {
                    try device.setTorchModeOn(level: level)
                    isOverHeating = true
                } catch _ {
                    isOverHeating = false
                }
                device.unlockForConfiguration()
            }
        }
        return isOverHeating
    }
    
    
    func turnOffFlash(){
        if let device = self.videoDevice{
            if (device.hasTorch && device.torchMode == AVCaptureDevice.TorchMode.on) {
                do {
                    try device.lockForConfiguration()
                } catch _ {
                }
                device.torchMode = AVCaptureDevice.TorchMode.off
                device.unlockForConfiguration()
            }
        }
    }
    
    
}

