//
//  VideoModel.swift
//  ImageLab
//
//  Created by Eric Cooper Larson on 10/12/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import MetalKit

class VideoModel: NSObject {
    
    //MARK: Class Properties
    private var filters : [CIFilter]! = nil
    private var videoManager:VisionAnalgesic! = nil
    private let pinchFilterIndex = 1
    weak var cameraView:MTKView?
    
    init(view:MTKView){
        super.init()
        
        cameraView = view
        
        self.setupFilters(view:view)
        
        self.videoManager = VisionAnalgesic(view: view)
        self.videoManager.setCameraPosition(position: .front)
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    //MARK: Setup filtering
    private func setupFilters(view:MTKView){
        filters = []
        
        // add bloom filter with new radius
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        // add pinch filter
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filterPinch.setValue(CIVector(x:view.bounds.size.height-50,y:view.bounds.size.width), forKey: "inputCenter")
        filters.append(filterPinch)
        
    }
    
    private func applyFilters(inputImage:CIImage)->CIImage{
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage
    }
    
    //MARK: Process image output
    private func processImage(inputImage:CIImage) -> CIImage{
        return applyFilters(inputImage: inputImage)
    }
    
    public func setFilterLocation(point:CGPoint){
        // this must be custom for each camera position and for each orientation
        // CoreImage has origin in lower left of landscape
        // UIKit has origin in upper left in portrait
        // also, if applying "flipped" or rotations with VideoANalgesic, that must be accounted for
        
        let scaling = videoManager.getViewScaling()
        
        let xVal = point.x * scaling.x
        let yVal = ((cameraView?.frame.maxY)! - point.y) * scaling.y
        let tmp = CIVector(x: xVal, y:yVal)
        
        self.filters[pinchFilterIndex].setValue(tmp, forKey: "inputCenter")
        
        print(point)
        print(tmp)

    }

}
