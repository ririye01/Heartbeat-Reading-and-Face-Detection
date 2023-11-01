//
//  TimerModel.swift
//  ImageLab
//
//  Created by Ethan Haugen on 10/31/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import Foundation
import UIKit

class TimerModel: NSObject {
    private var remainingTime: TimeInterval = 0
    var timeDisplay: String = "30:00"
    
    
    func changeDisplay(){
        let time = NSInteger(remainingTime)
        let seconds = time/100
        let millisecond = time%100
        
        timeDisplay = String(format:"%0.2d:%0.2d", seconds, millisecond)
    }
    
    func decrementRemainingTime() {
        remainingTime -= 5
    }
    
    func setRemainingTime(withInterval interval: TimeInterval){
        remainingTime = interval
    }
    
    func getRemainingTime() -> TimeInterval {
        return remainingTime
    }
    
}
