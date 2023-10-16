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

    
    @IBOutlet weak var cameraView: MTKView!
    var videoModel:VideoModel?
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoModel = VideoModel(view: self.cameraView)
    
    }
    
    

    @IBAction func panRecognized(_ sender: UIPanGestureRecognizer) {
        let uiPoint = sender.location(in: self.cameraView)
        videoModel?.setFilterLocation(point: uiPoint)

    }
    
    @IBAction func tapRecognized(_ sender: UITapGestureRecognizer) {
        let uiPoint = sender.location(in: self.cameraView)
                
        videoModel?.setFilterLocation(point: uiPoint)
    }
    
}

