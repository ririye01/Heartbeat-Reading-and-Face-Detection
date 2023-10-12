//
//  VideoModelVNDetector.swift
//  ImageLab
//
//  Created by Eric Cooper Larson on 10/12/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import MetalKit
import Vision

class VideoModelVNDetector: NSObject {

    weak var cameraView:MTKView?
    
    //MARK: Class Properties
    private var filters : [CIFilter]! = nil
    private lazy var videoManager:VisionAnalgesic! = {
        let tmpManager = VisionAnalgesic(view: cameraView!)
        tmpManager.setCameraPosition(position: .back)
        return tmpManager
    }()
    
    
    
    init(view:MTKView){
        super.init()
        
        cameraView = view
        
        self.setupFilters()
        
        self.videoManager.setCameraPosition(position: .front)
        self.videoManager.setVisionRequest(newVisionHandler:handleFaceDetect)
        
        
    }
    
    //MARK: Setup filtering
    private func setupFilters(){
        filters = []
        
        // starting values for filter
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filters.append(filterPinch)
        
    }
    
    //MARK: Apply filters and apply feature detectors
    
    func handleFaceDetect(_ faceObservations: [VNFaceObservation]) {
        if let obs = faceObservations.first{
            print(obs)
        }
        
    }
    
    
    
    
    
}
