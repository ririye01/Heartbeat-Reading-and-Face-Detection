//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let urlPath = Bundle.main.path(forResource: "smu-campus", ofType: "jpg")
        let fileURL = NSURL.fileURL(withPath: urlPath!)
        
        let beginImage = CIImage(contentsOf: fileURL)
        
        let filter = CIFilter(name: "CIBloom")!
        filter.setValue(beginImage, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputIntensityKey)
        filter.setValue(20, forKey: "inputRadius")
        
        let newImage = UIImage(ciImage: filter.outputImage!)
        self.imageView.image = newImage
        self.imageView.sizeThatFits(newImage.size)
    
    }


}

