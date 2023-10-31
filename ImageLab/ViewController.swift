
import UIKit
import AVFoundation
import MetalKit

class ViewController: UIViewController   {

 
    
    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VisionAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    var faceDetection:Bool = true
    
    //Heartrate variables
    var flash = false
    var fingerIsOnCamera = false
    var lastFlashToggleTime: Date? = nil
    
    //MARK: Outlets in view
    @IBOutlet weak var cameraView: MTKView!
    @IBOutlet weak var segmentSwitch: UISegmentedControl!
    @IBOutlet weak var cameraFlipButton: UIButton!
    @IBOutlet weak var heartBeatLabel: UILabel!
    @IBOutlet weak var heartBeatTimer: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        cameraFlipButton.isHidden = false
        cameraFlipButton.isEnabled = true
        heartBeatLabel.isHidden = true
        heartBeatLabel.isEnabled = false
        // setup the OpenCV bridge nose detector, from file
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VisionAnalgesic(view: self.cameraView)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        // Set a timer to ensure camera flash for finger doesn't show right away before camera loads
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in }
        
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,
                      CIDetectorNumberOfAngles:11,
                      CIDetectorTracking:false] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        if !self.videoManager.isRunning{
            self.videoManager.start()
        }
    
    }
    
    
    //MARK: Process Heartbeat image output
    func processImageSwift(inputImage:CIImage) -> CIImage {
        var retImage = inputImage
        
        // Set the image in the bridge for processing
        self.bridge.setImage(
            retImage,
            withBounds: retImage.extent,
            andContext: self.videoManager.getCIContext()
        )
        
        if(faceDetection == true){
            //code for face detection
            self.bridge.processImage()
        }
        else{
            // Check if a finger is detected
            let isFingerDetected = self.bridge.processFinger(self.fingerIsOnCamera)
            
            // Check if enough time has passed since the last flash toggle
            let canToggleFlash: Bool
            /// Use this lazy instantiation notation, because we initially declare the `lastToggle` Date variable as `nil`
            if let lastToggle = lastFlashToggleTime {
                canToggleFlash = Date().timeIntervalSince(lastToggle) > 1.0
            } else {
                canToggleFlash = true
            }
            
            // Logic to manage flashlight based on finger detection
            if isFingerDetected && !self.fingerIsOnCamera && canToggleFlash {
                // If finger is detected and flash is currently off, turn on the flash
                self.videoManager.turnOnFlashwithLevel(1)
                self.fingerIsOnCamera = true
                self.lastFlashToggleTime = Date()
            } else if !isFingerDetected && self.fingerIsOnCamera && canToggleFlash {
                // If no finger is detected and flash is currently on, turn off the flash
                self.videoManager.turnOffFlash()
                self.fingerIsOnCamera = false
                self.lastFlashToggleTime = Date()
            }
        }
        
        
        // Get the processed image from the bridge
        retImage = self.bridge.getImageComposite()
        
        return retImage
    }
    
    //MARK: Setup Face Detection
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            if self.bridge.processType <= 10 {
                self.bridge.processType += 1
            }
        case .right:
            if self.bridge.processType >= 1{
                self.bridge.processType -= 1
            }
        default:
            break
            
        }
        

    }
    
    //MARK: Toggle Between the Two Modules

    @IBAction func toggleViews(_ sender: UISegmentedControl) {
        switch segmentSwitch.selectedSegmentIndex 
        {
        case 0:
            toggleFaceDetection()
        case 1:
            toggleHeartbeat()
        default: break
        }
    }
    
    func toggleFaceDetection() {
        cameraFlipButton.isHidden = false
        cameraFlipButton.isEnabled = true
        heartBeatLabel.isHidden = true
        heartBeatLabel.isEnabled = false
        heartBeatTimer.isHidden = true
        heartBeatTimer.isEnabled = false
        self.faceDetection = true
    }
    
    func toggleHeartbeat() {
        cameraFlipButton.isHidden = true
        cameraFlipButton.isEnabled = false
        heartBeatLabel.isHidden = false
        heartBeatLabel.isEnabled = true
        heartBeatTimer.isHidden = false
        heartBeatTimer.isEnabled = true
        self.videoManager.setCameraPosition(position: .back)
        self.faceDetection = false
    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
        }
        else{
        }
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        self.videoManager.toggleCameraPosition()
    }
    
}

