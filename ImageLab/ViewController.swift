//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {

    @IBOutlet weak var imageView: UIImageView!
    var filters : [CIFilter]! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let urlPath = Bundle.main.path(forResource:"smu-campus", ofType: "jpg")
        let fileURL = NSURL.fileURL(withPath: urlPath!)
        
        let beginImage = CIImage(contentsOf: fileURL)
        
        self.setupFilters()
        
        let newImage = UIImage(ciImage: applyFilters(inputImage: beginImage!))
        self.imageView.image = newImage
    
    }
    
    func setupFilters(){
        filters = []
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        let filterHue = CIFilter(name:"CIHueAdjust")!
        filterHue.setValue(10.0, forKey: "inputAngle")
        // how could we set this filter to dynamically be adjusted?
        filters.append(filterHue)
    }
    
    func applyFilters(inputImage:CIImage)->CIImage{
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage
    }
    
    
    @IBAction func loadImage(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: nil)
        
        let image = info["UIImagePickerControllerOriginalImage"] as! UIImage
        let beginImage = CIImage(image: image)
        let newImage = UIImage(ciImage: applyFilters(inputImage: beginImage!), scale: CGFloat(1.0), orientation: image.imageOrientation)
        self.imageView.image = newImage
        
    }

}

