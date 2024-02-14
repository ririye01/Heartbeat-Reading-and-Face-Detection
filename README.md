# Handheld Heartbeat Reader

This application uses OpenCV to detect different red hues in a user's finger and interpret the count of these hue differentiations as heart beats per minute. A frame-by-frame plot of the average red pixellation in each frame over time in a time series plot can be seen below, and I then implemented a peak-finding algorithm to count each peak.

