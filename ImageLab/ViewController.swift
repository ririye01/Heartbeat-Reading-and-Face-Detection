//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        let filterHue = CIFilter(name:"CIHueAdjust")!
        filterHue.setValue(10.0, forKey: "inputAngle")
        filters.append(filterHue)
        
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filterPinch.setValue(CIVector(x:self.view.bounds.size.height-50,y:self.view.bounds.size.width), forKey: "inputCenter")
        filters.append(filterPinch)
        
    }
    
    func applyFilters(inputImage:CIImage)->CIImage{
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        return applyFilters(inputImage: inputImage)
    }

    @IBAction func panRecognized(_ sender: UIPanGestureRecognizer) {
        
            let point = sender.location(in: self.view)
            
            // this must be custom for each camera position and for each orientation
            let tmp = CIVector(x:point.y,y:self.view.bounds.size.width-point.x)
            self.filters[pinchFilterIndex].setValue(tmp, forKey: "inputCenter")
    }
    
}

