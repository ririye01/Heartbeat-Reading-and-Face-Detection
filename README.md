# ImageLab

1) Given that each float array is 100 points: how many milliseconds of data has been collected? Please describe your method for deriving this time span.

To determine the number of milliseconds of data that has been collected, we need to know the frame rate at which the data was captured. More recent iPhone's have defaulted their frame rate to 60 FPS, whereas older iPhones often have a default framerate of 30 FPS. Given we capture data for 100 frames, we can determine the time span for the captured data:

$$
Time\text{ }of\text{ }data\text{ }collected\text{ }(milliseconds) = \frac{Frames\text{ }captured}{FPS} = \frac{100}{FPS}
$$

For an iPhone capturing video at 30 FPS, the total milliseconds of data collected would be $\frac{100}{30} \approx 3.333$ milliseconds, whereas for an iPhone capturing video at 60 FPS, the total milliseconds of data collected would be $\frac{100}{60} \approx 1.667$ milliseconds.

2) 
