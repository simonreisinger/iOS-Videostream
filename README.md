# iosDepthRecording
<!--[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://mit-license.org)-->
[![Platform](http://img.shields.io/badge/platform-ios-lightgrey.svg)](https://developer.apple.com/resources/)
[![Language](https://img.shields.io/badge/swift-3.1-orange.svg)](https://developer.apple.com/swift)
[![Language](https://img.shields.io/badge/swift-4-orange.svg)](https://developer.apple.com/swift)


It streams color/depth data video/photo from an iPhone to a server where it is prosessed and replayed with a small delay

## Installation
### iPhone:
* iphoneApp/VideoLiveStreaming/VideoLiveStreamingDemo.xcodeproj mit XCODE Öffnen
* im Tab “General”
* den “Bundle Identifier” auf einen eigenen Namen stellen. Zum Beispiel “at.ac.tuwien.ims.YOURNAME”
* unter “Team” eine appleID/iTunes-Account hinzufügen und auswählen
* Im File “Classes/streamingConfiguration.plist” die Variablen “endpointUrlString” und “filtered” nach Wunsch einstellen 
* Projekt starten
* Bei Nachfrage der App die nötigen Rechte geben

#### Tutorial to get project running
* cmd+shift+k

## Desktop app
* Webserver Installieren (Mamp: https://www.mamp.info/de/; XAMP: https://www.apachefriends.org/de/index.html) und für andere Geräte den Zugriff über das Netzwerk zu freigeben.
* htdocs-Verzeichnis hintergrundvideos aus dem Properties ordner in einem Ordner ablegen. Die jeweeilige URL/den jeweiligen Pfad in der Desktop app und in der iPhone App korrigieren 
* Desktop app (Main.cpp) starten (erst 1 Sekunde nach dem in der iPhone App auf "Start streaming" gedrückt wurde)

## Resources:
* [Depth data](https://developer.apple.com/library/content/samplecode/AVCamPhotoFilter)
* [Video Streaming](https://github.com/MerchV/VideoLiveStreaming) (updated by us to Swift 4.0)
* Documentaion created with [jazzy](https://github.com/realm/jazzy)
* [iPhone wirless debugging](https://youtu.be/UFOiCESv0s4)

## NEXT THING TO IMPLEMENT:

### Future ideas:
* Being able to chang standardstreaming values in the app **permanently/save** user generated content (https://stackoverflow.com/questions/28628225/how-to-save-local-data-in-a-swift-app#28628776)
* create **init** Methods in iPhone app
* manuelle camera features hinzufügen (iso, Shutter speed ...)
* an iPhoneX anpassen
* APPLE WATCH APP ([nicht möglich](http://iaintheindie.com/2015/10/30/updating-apps-for-ios-9-part-2/))
* [Audio streaming/recording hinzufügen](https://iosdevcenters.blogspot.com/2016/05/audio-recording-and-playing-in-swift-30.html)
* Fehlermeldung bei snapshots von caches loeschen entfernen
* better code structering
* being able to save the images/videos to the apple library
* add [licence](https://github.com/chrisballinger/FFmpeg-iOS/blob/master/LICENSE)
* remove warnings from XCODE Project
* improve documentation
* Check file format in put.php

## Tested for:
* [XCODE](https://developer.apple.com/xcode) Version 9.4.1
* iPhone 7 plus  (iOS 11.4)
* [Mac OS](https://www.apple.com/macos) 10.13.x

## Acknowledgment
This project was implemented during a Practicum for the Research Divisions [Interactive Media Systems](https://www.ims.tuwien.ac.at/), ([TU Wien] (www.tuwien.ac.at)) 

## Authors
* Michael Pointner
* Simon Reisinger
