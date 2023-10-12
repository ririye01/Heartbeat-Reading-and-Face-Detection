//
//  VideoModel.swift
//  ImageLab
//
//  Created by Eric Cooper Larson on 10/11/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import MetalKit

class VideoModel: NSObject {
    
    //MARK: Class Properties
    private var filters : [CIFilter]! = nil
    private var videoManager:VisionAnalgesic! = nil
    
    init(with view:MTKView){
        super.init()
        
        // create array of filters
        self.setupFilters()
        
        // setup video manager with view to render and camera to use
        self.videoManager = VisionAnalgesic(view: view)
        self.videoManager.setCameraPosition(position: .back)
        
        // print the memory context for the filters, etc.
        print(self.videoManager.getCIContext()!)
       
        // what function to call between capture and render
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        // start processing!
        if !videoManager.isRunning{
            videoManager.start()
        }
        
        
    }
    
    //MARK: Setup and Apply Filtering Array
    private func setupFilters(){
        filters = []
        
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        let filterHue = CIFilter(name:"CIHueAdjust")!
        filterHue.setValue(10.0, forKey: "inputAngle")
        filters.append(filterHue)
        
    }
    
    private func applyFilters(inputImage:CIImage)->CIImage{
        // basically the same as last time
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage
    }
    
    //MARK: Process image output
    private func processImage(inputImage:CIImage) -> CIImage{
        //return inputImage
        return applyFilters(inputImage: inputImage)
    }
    
    //MARK: Public Access Functions
    func setHue(hue:Float){
        let hueIndex = 1
        filters[hueIndex].setValue(hue, forKey: "inputAngle")
        
        
    }
    
    func setBloomIntensity(intensity:Float){
        let bloomIndex = 0
        // set if condition? true:false
        let tmpIntensity = (intensity >= Float.pi) ? 0.0 : 0.5
        filters[bloomIndex].setValue(tmpIntensity, forKey: kCIInputIntensityKey)
    }
    

}
