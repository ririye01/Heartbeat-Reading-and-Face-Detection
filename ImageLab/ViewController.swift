//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        
        // the remainder of this example should probably be in
        // a model somewhere, rather than in the VC (but just a quick example)
        
        // create array of filters
        self.setupFilters()
        
        // setup video manager with view to render and camera to use
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: .front)
       
        // what function to call between capture and render
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        // start processing!
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    @IBAction func updateHue(_ sender: UISlider) {
        let hueIndex = 1
        filters[hueIndex].setValue(sender.value, forKey: "inputAngle")
    }
    
    //MARK: Setup and Apply Filtering Array
    func setupFilters(){
        filters = []
        
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        let filterHue = CIFilter(name:"CIHueAdjust")!
        filterHue.setValue(10.0, forKey: "inputAngle")
        filters.append(filterHue)
        
    }
    
    func applyFilters(inputImage:CIImage)->CIImage{
        // basically the same as last time
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        return inputImage
        //return applyFilters(inputImage: inputImage)
    }

}

