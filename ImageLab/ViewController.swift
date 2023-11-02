
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
        
        self.videoManager = VisionAnalgesic(view: self.cameraView)
        
        //Start on face detection view
        toggleFaceDetection()
        
        // Create graph
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            
            graph.addGraph(withName: "time",
                           numPointsInGraph: self.bridge.framesCapturedThreshold)

            graph.makeGrids() // add grids to graph
        }
        
        // FIX: MIGHT NOT NEED THIS SINCE STARTING ON FACE MODE
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
        
        //checks the mode user is on
        if(faceDetection == true){
            
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
            /// Use this lazy instantiation notation, because we initially declare the `lastToggle` Date variable as `nil`
            if let lastToggle = lastFlashToggleTime {
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
                
                self.graphView.isHidden = false
                graphTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
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
                stopTimer(finished:false)
                heartBeatTimer.text = timerModel.timeDisplay
                heartBeatLabel.text = "Place Finger Over Camera To Record Heart Rate"
                self.graphView.isHidden = true
                graphTimer?.invalidate()
                graphTimer = nil
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
    
    // Function to change the label from the hearbeat reading back to stopwatch
    @objc func resetHeartbeatReading(){
        heartBeatTimer.text = self.bridge.getHeartrateText()
        //If the finger is already back on the camera, the stopwatch will already be reset and started
        if(!self.fingerIsOnCamera){
            heartBeatLabel.text = "Place Finger Over Camera To Record Heart Rate"
            heartBeatTimer.text = timerModel.timeDisplay
            // Invalidate the timer used to trigger this function
            resetTimer?.invalidate()
            resetTimer = nil
        }
    }
    
    // Timer for the stopwatch counting down from 33 seconds. Go by 5 hundredths of a second
    // because going every .01 is too fast, lags the timer
    func startTimer(){
            timerModel.setRemainingTime(withInterval: 3300)
            timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            // Let user know that they are doing the right thing
            heartBeatLabel.text = "Recording Heart Rate..."
    }
    
    //Function to update stopwatch label
    @objc private func updateTimer(){
        if timerModel.getRemainingTime() > 0 {
            timerModel.decrementRemainingTime()
            timerModel.changeDisplay()
            heartBeatTimer.text = timerModel.timeDisplay
        }
        else{
            // Stop timer with finished set to TRUE, since it got to 0
            self.stopTimer(finished:true)
        }
        
    }
    
    // Stops the stopwatch timer, bool states whether it finished or finger was removed
    func stopTimer(finished:Bool){
        timer?.invalidate()
        timer = nil
        timerModel.setRemainingTime(withInterval: 3300)
        timerModel.changeDisplay()
        // Only if it finishes do we display the heartbeats, and start the reset timer
        if(finished){
            heartBeatTimer.text = self.bridge.getHeartrateText()
            heartBeatLabel.text = ""
            // Reset timer will continuously check the for removal of the finger, and replace heartbeat reading with timer once removed
            resetTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(resetHeartbeatReading), userInfo: nil, repeats: true)
        }
    }
    
    //MARK: Toggle Between the Two Modules
    // Segmented switch toggles views based on face detection and heartbeat settings
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
    
    // switches which views are diplayed and enabled to only the camera switch button
    func toggleFaceDetection() {
        cameraFlipButton.isHidden = false
        cameraFlipButton.isEnabled = true
        heartBeatLabel.isHidden = true
        heartBeatLabel.isEnabled = false
        heartBeatTimer.isHidden = true
        heartBeatTimer.isEnabled = false
        self.faceDetection = true
        self.videoManager.turnOffFlash()
        
        
        
    }
    
    //switches to the stopwatch and heartbeat label views
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
    
    func updateGraph() {
        if let redValues = bridge.avgRedValues {
            var normalizedValues: [Float] = []
            
            for value in redValues {
                let num = value as! Double
                let normalizedValue = Float(num)/128-1
                normalizedValues.append(normalizedValue)
            }
            
            if let graph = self.graph{
                graph.updateGraph(
                    data: normalizedValues,
                    forKey: "time"
                )
            }
        } else {
            
        }
        
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

