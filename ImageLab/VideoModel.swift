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
    
    weak var cameraView:MTKView?
    
    //MARK: Class Properties
    private var filters : [CIFilter]! = nil
    private lazy var videoManager:VisionAnalgesic! = {
        let tmpManager = VisionAnalgesic(view: cameraView!)
        tmpManager.setCameraPosition(position: .front)
        return tmpManager
    }()
    
    private lazy var detector:CIDetector! = {
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,
                            CIDetectorTracking:false,
                      CIDetectorMinFeatureSize:0.1,
                     CIDetectorMaxFeatureCount:1,
                      CIDetectorNumberOfAngles:11] as [String : Any]
        
        // setup a face detector in swift
        let detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        return detector
    }()
    
    init(view:MTKView){
        super.init()
        
        cameraView = view
        
        self.setupFilters()
        
        self.videoManager.setCameraPosition(position: .front)
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
        
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
    private func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint() // for saving the center of face
        var radius = 75
        
        for face in features { // for each face
            //set where to apply filter
            filterCenter.x = face.bounds.midX
            filterCenter.y = face.bounds.midY
            radius = Int(face.bounds.width/2) // for setting the radius of the bump
            
            //do for each filter (assumes all filters have property, "inputCenter")
            for filt in filters{
                filt.setValue(retImage, forKey: kCIInputImageKey)
                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                filt.setValue(radius, forKey: "inputRadius")
                //  also manipulate the radius of the filter based on face size!
                retImage = filt.outputImage!
            }
        }
        return retImage
    }
    
    private func getFaces(img:CIImage) -> [CIFaceFeature]{
        // makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
    }
    
    //MARK: Process image output
    private func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let faces = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if faces.count == 0 { return inputImage }
        
        //otherwise apply the filters to the faces
        return applyFiltersToFaces(inputImage: inputImage, features: faces)
    }

}
