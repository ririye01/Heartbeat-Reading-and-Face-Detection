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

    var videoModel:VideoModel? = nil
    @IBOutlet weak var cameraView: MTKView!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // run videoModel with the specified MTKView
        videoModel = VideoModel(with: self.cameraView)
    
    }
    
    @IBAction func updateHue(_ sender: UISlider) {
        // Update some filter parameters 
        videoModel?.setHue(hue: sender.value)
        videoModel?.setBloomIntensity(intensity: sender.value)

    }
    
    

}

