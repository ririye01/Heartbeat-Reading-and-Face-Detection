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
        
        // add some bloom, soft glowing edges
        let filterBloom = CIFilter(name: "CIBloom")!
        filterBloom.setValue(0.5, forKey: kCIInputIntensityKey)
        filterBloom.setValue(20, forKey: "inputRadius")
        filters.append(filterBloom)
        
        // shift the colors around...
        let filterHue = CIFilter(name:"CIHueAdjust")!
        filterHue.setValue(10.0, forKey: "inputAngle")
        // how could we set this filter to dynamically be adjusted?
        filters.append(filterHue)
        
        // make it sepia?
        let filterSepia = CIFilter(name: "CISepiaTone")!
        filters.append(filterSepia)
    }
    
    func applyFilters(inputImage:CIImage)->CIImage{
        // start with the original image, setup pipeline
        var retImage = inputImage
        for filt in filters{
            filt.setValue(retImage, forKey: kCIInputImageKey)
            retImage = filt.outputImage!
        }
        return retImage // the output of this goes through all filters
    }
    
    // present camera UI, setup self as delegate
    @IBAction func loadImage(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
    }
    
    // user canceled, do nothing
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    

    // user selected an images, grab it and filter
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        self.dismiss(animated: true, completion: nil)
        
        if let image = info["UIImagePickerControllerOriginalImage"] as? UIImage{
            var beginImage = CIImage(image: image)!
            // we have just lost the meta data for orientation
            // and would need to map CI and UI team's code to fix, ugh
            beginImage = applyFilters(inputImage: beginImage)
            
            let newImage   = UIImage(ciImage: beginImage,
                                       scale: CGFloat(1.0),
                                     orientation: image.imageOrientation)
            
            
            DispatchQueue.main.async{
                self.imageView.image = newImage
                // band-aid solution... just rotate the view
                self.imageView.transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi/2))
            }
        }
        
    }

}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}
