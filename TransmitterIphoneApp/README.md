# iOSDepthRecording
<!--[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://mit-license.org)-->
[![Platform](http://img.shields.io/badge/platform-ios-lightgrey.svg)](https://developer.apple.com/resources/)
[![Language](https://img.shields.io/badge/swift-3.1-orange.svg)](https://developer.apple.com/swift)
[![Language](https://img.shields.io/badge/swift-4-orange.svg)](https://developer.apple.com/swift)

This project was implemented during a Practicum for the Research Divisions [Interactive Media Systems](https://www.ims.tuwien.ac.at/),  ([TU Wien](www.tuwien.ac.at)) 

An iOS App for  iPhones with Dual Cameras which streams Video and Depth Data to a server using Apple HLS format. 

Most of the action happens in Classes/ViewController.swift. First, set your endpoint (and the other settings) in Classes/streamingConfiguration.plist. This can be a PHP file on your publicly-visible web host. 

Your PHP file can look like this:
```php
<?php
$putdata = fopen("php://input", "r");
$fp = fopen($_GET['filename'], "w");
while ($data = fread($putdata, 1024))
  fwrite($fp, $data);
fclose($fp);
fclose($putdata);
?>
```
## Resources:
* [Depth data](https://developer.apple.com/library/content/samplecode/AVCamPhotoFilter)
* [Rudimentary Video Streaming using Apple HLS format](https://github.com/MerchV/VideoLiveStreaming)
* Documentaion created with [jazzy](https://github.com/realm/jazzy)
* [iPhone wirless debugging](https://youtu.be/UFOiCESv0s4)

### The Xcode project includes (already built)
* [FFmpegWrapper](https://github.com/OpenWatch/FFmpegWrapper)
* [FFmpeg-iOS](https://github.com/chrisballinger/FFmpeg-iOS)

## Requierements
* iPhone with Dual Cameras
* iOS 11.x+
* Xcode 11+
* Swift 4.0+

## Authors
* [Michael Pointner](https://github.com/mpointner)
* [Simon Reisinger](https://www.simonreisinger.com)

