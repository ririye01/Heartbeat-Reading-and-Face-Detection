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

    
    @IBOutlet weak var camerView: MTKView!
    var videoModel:VideoModel?
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoModel = VideoModel(view: self.camerView)
    
    }
    
    

    @IBAction func panRecognized(_ sender: UIPanGestureRecognizer) {
        
        let uiPoint = sender.location(in: self.camerView)
        
        videoModel?.setFilterLocation(point: uiPoint)
        
        // this must be custom for each camera position and for each orientation
        // CoreImage has origin in lower left of landscape
        // UIKit has origin in upper left in portrait
        // also, if applying "flipped" or rotations with VideoANalgesic, that must be accounted for
        
    }
    
    @IBAction func tapRecognized(_ sender: UITapGestureRecognizer) {
        let uiPoint = sender.location(in: self.camerView)
        
        // this must be custom for each camera position and for each orientation
        
        videoModel?.setFilterLocation(point: uiPoint)
    }
    
}

