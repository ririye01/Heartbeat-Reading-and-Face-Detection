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
    let pinchFilterIndex = 1
    
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
        
        // add bloom filter
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        // add pinch filter
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
        
        let uiPoint = sender.location(in: self.view)
        
        // this must be custom for each camera position and for each orientation
        // CoreImage has origin in lower left of landscape
        // UIKit has origin in upper left in portrait
        // also, if applying "flipped" or rotations with VideoANalgesic, that must be accounted for
        let tmp = CIVector(x:uiPoint.y,
                           y:uiPoint.x)
        self.filters[pinchFilterIndex].setValue(tmp, forKey: "inputCenter")
    }
    
    @IBAction func tapRecognized(_ sender: UITapGestureRecognizer) {
        let uiPoint = sender.location(in: self.view)
        
        // this must be custom for each camera position and for each orientation
        let tmp = CIVector(x:uiPoint.y,
                           y:uiPoint.x)
        
        self.filters[pinchFilterIndex].setValue(tmp, forKey: "inputCenter")
    }
    
}

