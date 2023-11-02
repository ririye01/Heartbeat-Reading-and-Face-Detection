
import UIKit
import AVFoundation
import MetalKit

class ViewController: UIViewController   {

 
    
    //MARK: Class Properties
    // Camera variables
    var filters : [CIFilter]! = nil
    var videoManager:VisionAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    
    // Face Detection Variables
    var faceDetection:Bool = true
    
    // Heartrate variables
    var flash = false
    var fingerIsOnCamera = false
    var lastFlashToggleTime: Date? = nil
    var timer: Timer?
    var resetTimer: Timer?
    var graphTimer: Timer?
    
    
    //MARK: Outlets in view
    @IBOutlet weak var cameraView: MTKView!
    @IBOutlet weak var segmentSwitch: UISegmentedControl!
    @IBOutlet weak var graphView: UIView!

    
    // Only visible on Face Detection Mode
    @IBOutlet weak var cameraFlipButton: UIButton!
    
    // Only visible on Heartbeat Detection Mode
    @IBOutlet weak var heartBeatLabel: UILabel!
    @IBOutlet weak var heartBeatTimer: UILabel!
    
    
    // Model to retain stopwatch time
    lazy var timerModel: TimerModel = {
        return TimerModel()
    }()
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.graphView)
    }()

    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        
        // Declare video manager with VisionAnalgesic
        self.videoManager = VisionAnalgesic(view: self.cameraView)
        
        //Start on face detection view
        self.enableFaceDetectionMode()
        
        // Create graph
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            
            graph.addGraph(withName: "time",
                           shouldNormalizeForFFT: false,
                           numPointsInGraph: self.bridge.framesCapturedThreshold)

            graph.makeGrids() // add grids to graph
        }
        
        // Set a timer to ensure camera flash for finger doesn't show right away before camera loads
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in }
        
        // create dictionary for face detection
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
        
        // CHECKS IF THE FACE DETECTION IN SEGMENTED SWITCH IS LISTED AS ON
        if(self.faceDetection == true){
            
            // Get faces, return if none found
            let faces = getFaces(img: retImage)
            if faces.count == 0 { return inputImage }
            
            // Loop through faces
            for face in faces{
                // Get eye positions, and translate into usable coordinates
                var pt1 = face.rightEyePosition
                var pt2 = face.leftEyePosition
                var dif = abs(pt1.x - pt2.x)
                var x1 = pt1.x - dif
                var y1 = 962.0-pt1.y + 962.0 - dif / 2
                var x2 = pt2.x + dif
                var y2 = 962.0-pt2.y + 962.0 + dif / 2
                
                // Draw box around calculated coordinates for eyes
                self.bridge.drawBoxX(Float(x1), toY: Float(y1), andX: Float(x2), andY: Float(y2))
                
                // Get face position and translate into usable coordinates
                pt1 = face.mouthPosition
                x1 = pt1.x - dif / 2
                y1 = 962.0-pt1.y + 962.0 - dif / 4
                x2 = pt1.x + dif / 2
                y2 = 962.0-pt1.y + 962.0 + dif / 3
                
                // Draw box around calculated coordinates for mouth
                self.bridge.drawBoxX(Float(x1), toY: Float(y1), andX: Float(x2), andY: Float(y2))
            }
        }
        else{
            // Finger Detection Mode, check for finger
            let isFingerDetected = self.bridge.processFinger(self.fingerIsOnCamera)
            
            // Check if enough time has passed since the last flash toggle
            let canToggleFlash: Bool
            /// Use this notation, because we initially declare the `lastToggle` Date variable as `nil`
            if let lastToggle = self.lastFlashToggleTime {
                canToggleFlash = Date().timeIntervalSince(lastToggle) > 1.0
            } else {
                canToggleFlash = true
            }
            
            // Logic to manage flashlight based on finger detection
            if isFingerDetected && !self.fingerIsOnCamera && canToggleFlash {
                // If finger is detected and flash is currently off, do the following:
                // 1. Turn on flash
                self.videoManager.turnOnFlashwithLevel(1)
                // 2. Set the boolean that represents if a finger was in the previous frame
                self.fingerIsOnCamera = true
                // 3. Set the last toggle time to prevent rapid flashing
                self.lastFlashToggleTime = Date()
                // 4. Start the stopwatch
                self.startTimer()
                // 5. Disable Segmented Switch
                self.segmentSwitch.isEnabled = false
                // 6. Display graph and schedule timer for update
                self.graphView.isHidden = false
                self.graphTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    self.updateGraph()
                }
                
            } else if !isFingerDetected && self.fingerIsOnCamera && canToggleFlash {
                // If no finger is detected and flash is currently on, do the following:
                // 1. Turn off flash
                self.videoManager.turnOffFlash()
                // 2. Set the boolean to no finger in the previous frame
                self.fingerIsOnCamera = false
                // 3. Set the last toggle time
                self.lastFlashToggleTime = Date()
                // 4. Stop the stopwatch display prematurely, and reset the stopwatch and label displays
                self.stopTimer(finished:false)
                // 5. Enable Segmented Switch
                self.segmentSwitch.isEnabled = true
                
                // 6. Begin heartbeat logic
                self.heartBeatTimer.text = self.timerModel.timeDisplay
                self.heartBeatLabel.text = "Place Finger Over Camera To Record Heart Rate"
                self.graphView.isHidden = true
                self.graphTimer?.invalidate()
                self.graphTimer = nil
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
    
    // Function to change the label from the hearbeat reading back to stopwatch
    @objc func resetHeartbeatReading(){
        self.heartBeatTimer.text = self.bridge.getHeartrateText()
        //If the finger is already back on the camera, the stopwatch will already be reset and started
        if(!self.fingerIsOnCamera){
            self.heartBeatLabel.text = "Place Finger Over Camera To Record Heart Rate"
            self.heartBeatTimer.text = self.timerModel.timeDisplay
            // Invalidate the timer used to trigger this function
            self.resetTimer?.invalidate()
            self.resetTimer = nil
        }
    }
    
    // Timer for the stopwatch counting down from 33 seconds. Go by 5 hundredths of a second
    // because going every .01 is too fast, lags the timer
    func startTimer(){
        self.timerModel.setRemainingTime(withInterval: 3300)
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateTimer()
        }
            // Let user know that they are doing the right thing
        self.heartBeatLabel.text = "Recording Heart Rate..."
    }
    
    //Function to update stopwatch label
    @objc private func updateTimer(){
        if self.timerModel.getRemainingTime() > 0 {
            self.timerModel.decrementRemainingTime()
            self.timerModel.changeDisplay()
            self.heartBeatTimer.text = self.timerModel.timeDisplay
        }
        else{
            // Stop timer with finished set to TRUE, since it got to 0
            self.stopTimer(finished:true)
        }
        
    }
    
    // Stops the stopwatch timer, bool states whether it finished or finger was removed
    func stopTimer(finished:Bool){
        self.timer?.invalidate()
        self.timer = nil
        self.timerModel.setRemainingTime(withInterval: 3300)
        self.timerModel.changeDisplay()
        // Only if it finishes do we display the heartbeats, and start the reset timer
        if(finished){
            self.heartBeatTimer.text = self.bridge.getHeartrateText()
            self.heartBeatLabel.text = ""
            // Reset timer will continuously check the for removal of the finger, and replace heartbeat reading with timer once removed
            self.resetTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.resetHeartbeatReading()
            }
        }
    }
    
    //MARK: Toggle Between the Two Modules
    // Segmented switch toggles views based on face detection and heartbeat settings
    @IBAction func toggleViews(_ sender: UISegmentedControl) {
        switch segmentSwitch.selectedSegmentIndex 
        {
        case 0:
            self.enableFaceDetectionMode()
        case 1:
            self.enableHeartbeatMode()
        default: 
            break
        }
    }
    
    // Chain of logic to run when face detection mode happens
    func enableFaceDetectionMode() {
        // 1. Enable camera flip button to allow user to use camera
        self.cameraFlipButton.isHidden = false
        self.cameraFlipButton.isEnabled = true
        
        // 2. Hide heartbeat label in face detection mode
        self.heartBeatLabel.isHidden = true
        self.heartBeatLabel.isEnabled = false
        
        // 3. Hide heartbeat timer in face detection mode
        self.heartBeatTimer.isHidden = true
        self.heartBeatTimer.isEnabled = false
        
        // 4. Enable face detection mode
        self.faceDetection = true
        
        // 5. Turn the flash off
        self.videoManager.turnOffFlash()
    }
    
    // Chain of logic to run when heartbeat tracking mode happens
    func enableHeartbeatMode() {
        // 1. Disable camera flipping ability in heartbeat tracking mode
        self.cameraFlipButton.isHidden = true
        self.cameraFlipButton.isEnabled = false
        
        // 2. Enable functionality for heartbeat label
        self.heartBeatLabel.isHidden = false
        self.heartBeatLabel.isEnabled = true
        
        // 3. Enable functionality for heartbeat timer
        self.heartBeatTimer.isHidden = false
        self.heartBeatTimer.isEnabled = true
        
        // 4. Set to back camera mode because that's the only camera we need for heartbeat
        //    detection
        self.videoManager.setCameraPosition(position: .back)
        
        // 5. Disable face detection mode
        self.faceDetection = false
    }
    
    // Continuously update metal graph for tracking heartbeat
    func updateGraph() {
        // Access the average red values array from the OpenCV Bridge
        if let redValues = self.bridge.avgRedValues {
            // Create empty array of floats for normalized values to plot
            var normalizedValues: [Float] = []
            
            // Iterate through the red values
            for value in redValues {
                // Obtain float values, normalize them, then append them to the
                // normalized values array
                let num = value as! Double
                let normalizedValue = Float(num)/128 - 1
                normalizedValues.append(normalizedValue)
            }
            
            // Update graph by inputting new normalized values array
            if let graph = self.graph{
                graph.updateGraph(
                    data: normalizedValues,
                    forKey: "time"
                )
            }
        } else {
            print("Error gathering values")
        }
        
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        self.videoManager.toggleCameraPosition()
    }
 
    
}
