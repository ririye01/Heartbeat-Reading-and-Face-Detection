//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import CoreImage

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    var beginImage:CIImage?
    var filter:CIFilter?
    var outputImage: CIImage? {
        didSet{
            // also update UIImage
            if let image = outputImage{
                DispatchQueue.main.async {
                    self.imageView.image = UIImage(ciImage: image)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load image from bundle
        // set starting image be file image
        if let urlPath = Bundle.main.path(forResource: "smu-campus", ofType: "jpg"),
           let image = CIImage(contentsOf: NSURL.fileURL(withPath: urlPath)){
            self.beginImage = image
            
            // setup a filter
            filter = CIFilter(name: "CIColorClamp")
            // notice that this is the only place the input filter is set
            filter?.setValue(beginImage, forKey: kCIInputImageKey)
            
            // set image to be default
            outputImage = beginImage
        }
        
        
    
    }

    @IBAction func intensitySliderChange(_ sender: UISlider) {
        // adjust clamping of the filter
        let val = CGFloat(sender.value)
        filter?.setValue(CIVector(values:[1.0,val,1.0,1.0], count:4 ),
                         forKey: "inputMaxComponents")
        self.outputImage = filter?.outputImage
    }
    
    @IBAction func minValueChanged(_ sender: UISlider) {
        let val = CGFloat(sender.value)
        filter?.setValue(CIVector(values:[val,0.0,0.0,0.0], count:4 ),
                         forKey: "inputMinComponents")
        self.outputImage = filter?.outputImage
    }
    
    //var currentImage:CIImage?
    @IBAction func makeThermal(_ sender: UIButton) {
        
        let tmpFilter = CIFilter(name: "CIThermal")
        tmpFilter?.setValue(beginImage, forKey: "inputImage")
        beginImage = tmpFilter?.outputImage
        
        self.outputImage = beginImage
        
        // Todo: how can we clamp the thermal image???
        // Are there any bugs in the output, how?
        // INSERT CODE AS CLASS HERE to Make desired representations
        
        
    }
}

