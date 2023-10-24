# Flipped Module 3: OpenCV for iOS Finger Detection

## Developers

- Reece Iriye
- Ethan Haugen
- Chris Miller
- Rafe Forward

1) Given that each float array is 100 points: how many milliseconds of data has been collected? Please describe your method for deriving this time span.

To determine the number of milliseconds of data that has been collected, we need to know the frame rate at which the data was captured. More recent iPhone's have defaulted their frame rate to 60 FPS, whereas older iPhones often have a default framerate of 30 FPS. Given we capture data for 100 frames, we can determine the time span for the captured data:

$$
Time\text{ }of\text{ }data\text{ }collected\text{ }(milliseconds) = \frac{Frames\text{ }captured}{FPS} \times 1000 = \frac{100}{FPS} \times 1000
$$

For an iPhone capturing video at 30 FPS, the total milliseconds of data collected would be $\frac{100}{30} \times 1000 \approx 3,333.33$ milliseconds, whereas for an iPhone capturing video at 60 FPS, the total milliseconds of data collected would be $\frac{100}{60} \times 1000 \approx 1,666.67$ milliseconds.

2) Does this project correctly adhere to the paradigm of Model View Controller? Why or why not?

This project does not strictly and correctly adhere to the MVC paradigm throughout the codebase, because the View Controller contains some logic that should be in a Model to truly be more reminiscent of the MVC paradigm. For example, let's take a look at the `processImageSwift` function. 

In this function first off, the data and UI logic is intertwined and somewhat mixed. Specifically, the function checks if a finger is detected, which is data processing, and then based on this information, it modifies the state of the flash and the state of UI elements (`toggleFlashButton` and `toggleCameraButton`). In a strict MVC paradigm, the Controller should merely relay the information from the Model to the View and vice versa, without making decisions on both data and UI in the same function. The function also directly manages the flashlight with `self.videoManager.turnOnFlashwithLevel(1)` and `self.videoManager.turnOffFlash()`. This is more related to data and device management, which might be better placed in a model if we were trying to fully adhere to the MVC paradigm. Additionally, the function directly modifies the enabled state of UI elements with `self.toggleFlashButton.isEnabled = uiElementsEnabled` and `self.toggleCameraButton.isEnabled = uiElementsEnabled`. While a Controller does interact with the View, having this logic intermixed with data processing and torch management makes it less MVC-like.
