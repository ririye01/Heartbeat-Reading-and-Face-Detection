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
    // Maintain variables for storing the remaining time left in the timer and the time display
    private var remainingTime: TimeInterval = 0
    var timeDisplay: String = "30:00"
    
    // Control logic for changing the display as the timer clicks down
    func changeDisplay(){
        let time = NSInteger(remainingTime)
        let seconds = time/100
        let millisecond = time%100

        // Ensure that time display is in the format of seconds:milliseconds for readability
        timeDisplay = String(format:"%0.2d:%0.2d", seconds, millisecond)
    }

    // Decrease time by 5 milliseconds to ensure updates aren't too frequent
    func decrementRemainingTime() {
        remainingTime -= 5
    }

    // Allow parameter to be fed in through VC logic to call this function and adjust the timer
    // model's remaining time left
    func setRemainingTime(withInterval interval: TimeInterval){
        remainingTime = interval
    }

    // Retrieve the remaining time left as a TimeInterval type
    func getRemainingTime() -> TimeInterval {
        return remainingTime
    }
}
