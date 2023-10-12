//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import MetalKit

class ViewController: UIViewController   {

    var videoModel:VideoModelVNDetector? = nil
    
    @IBOutlet weak var cameraView: MTKView!
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoModel = VideoModelVNDetector(view: self.cameraView)
    
    }
    
    
    
    

   
}

