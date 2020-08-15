import UIKit
import AVFoundation
import CoreMedia
import VideoToolbox

import Zip

/**
 Controlls a storyboard. Can Stream Depth and Video Data to a Webserver
 - Authors: Michael Pointner, Simon Reisinger, mvisoiu
 - Note: Based on [VideoLiveStreaming](https://github.com/MerchV/VideoLiveStreaming) from mvisoiu
 */
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, AVCaptureDataOutputSynchronizerDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    //###################################################################
    //################## SET YOUR SERVER ENDPOINT HERE ##################
    //###################################################################
    /// URL endpoint, where the **RGB** / **Deapth** -Videos are streamed to
    private var endpointUrlString: String?
    /// getter and setter Methode for endpointUrlString
    public var EndpointUrlString: String {
        get {
            return endpointUrlString!
        }
        set {
            endpointUrlString = newValue
        }
    }

    /// streamingFrequency of the streamed video in Seconds
    private var sendVideoAllXSeconds: Double?
    /// Provides setter and getter for the **streamingFrequency**
    public var StreamingFrequency: Double {
        get {
            return self.sendVideoAllXSeconds!
        }
        set {
            self.sendVideoAllXSeconds = newValue
        }
    }

    /// Stores the selected option if the image is transmitted **filtered** or not
    private var filtered: Bool? // = true // Depth image filtered
    /// Provides setter and getter for the **filter**
    public var FilterDepth: Int {
        get {
            return filtered! ? 0 : 1
        }
        set {
            filtered = newValue == 0
        }
    }

    /// Stores **width** of the streamed video
    private var streamWidth: Int?
    /// Provides setter and getter for the **streamWidth**
    public var StreamWidth: Int {
        get {
            return streamWidth!
        }
        set {
            streamWidth = newValue
        }
    }

    /// Stores **height** of the streamed video
    private var streamHeight: Int?
    /// Provides setter and getter for the **streamHeight**
    public var StreamHeight: Int {
        get {
            return streamHeight!
        }
        set {
            streamHeight = newValue
        }
    }
    
    private var saveVideoPNG: Bool?
    
    private var minDisparity: Double?
    
    private var maxDisparity: Double?

    private var capturePhoto = false

    //###################################################################
    private var marginForButtons = CGFloat(20.0)
    private var avAssetWriterVideo = [AVAssetWriter?]()
    private var avAssetWriterVideoInput = [AVAssetWriterInput?]()
    private var session: AVCaptureSession!
    private var input: AVCaptureDeviceInput!
    private var device: AVCaptureDevice!
    private var currentIndexVideo: Int!
    private var currentIndexDepthBinary: Int!
    private var maxTimer: Timer?
    private var ffmpegWrapper: FFmpegWrapper!
    private var streamButton: UIButton!
    private var takePhotoButton: UIButton!
    private var takeLocalPhotoButton: UIButton!
    /// Stores if App is currently Streaming
    private var isStreaming = false
    private var countFramesinStream : Int = 0;
    private var countSecondsinStream : Double = 0;
    
    private var globalFrameCounter = 0
    
    private var binaryDepthData: [Data] = []

    private var activeVideoWritingIndex = 0
    private var activeVideoStreamingIndex = 0
    private var activeDepthBinaryWritingIndex = 0
    private var activeDepthBinaryStreamingIndex = 0

    private let avAssetWriterSyncronizedQueue = DispatchQueue(label: "at.ac.tuwien.ims.avAssetWriterSyncronizedQueue")

    private var alternate = 1
    private var depthTimingInfo: CMSampleTimingInfo = CMSampleTimingInfo.init() // Review
    private var finishedWritingVideo = true;
    
    /// Previews the output data from the RGB camera on the screen
    @IBOutlet var preview: UIView!

    private let videoDepthConverter = DepthToGrayscaleConverter()
    private let imageDepthConverter = DepthToGrayscaleConverter()

    private var currentDepthPixelBuffer: CVPixelBuffer? // Review

    // adding for depth image
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var currentDepthConnectionOrientation: AVCaptureVideoOrientation!

    // adding photos
    private let stillImageOutput = AVCapturePhotoOutput()

    /**
     Updates the orientation of the connection of the depth data video when the device changes orientation.
     */
    private var DepthDataOutputConnectionOrientation: AVCaptureVideoOrientation {
        get {
            return currentDepthConnectionOrientation
        }
        set {
            if (currentDepthConnectionOrientation != newValue) {
                DispatchQueue.main.async {
                    self.currentDepthConnectionOrientation = newValue
                    self.depthDataOutput.connection(with: .depthData)?.videoOrientation = newValue
                }
            }
        }
    }

    /**
     Updates the orientation of the depth data video when the device changes orientation.
     */
    private func updateDepthVideoOrientation(){
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
            DepthDataOutputConnectionOrientation = .landscapeRight  // TODO why
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight{
            DepthDataOutputConnectionOrientation = .landscapeLeft// TODO why
        } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            DepthDataOutputConnectionOrientation = .portrait
        } else {
            DepthDataOutputConnectionOrientation = .portrait
        }

    }

    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var currentvideoConnectionOrientation: AVCaptureVideoOrientation!

    /**
     Updates the orientation of the connection of the color video when the device changes orientation.
     */
    private var VideoDataOutputConnectionOrientation: AVCaptureVideoOrientation {
        get {
            return currentvideoConnectionOrientation
        }
        set {
            if (currentvideoConnectionOrientation != newValue) {
                DispatchQueue.main.async {
                    self.currentvideoConnectionOrientation = newValue
                    self.videoDataOutput.connection(with: .video)?.videoOrientation = newValue
                }
            }
        }
    }

    // MARK: - Update Orientaion (when device does change the orientation)

    /**
     Updates the orientation of the color video when the device changes orientation.
     */
    private func updateVideoOrientation(){
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
            VideoDataOutputConnectionOrientation = .landscapeRight // TODO why
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight{
            VideoDataOutputConnectionOrientation = .landscapeLeft // TODO why
        } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            VideoDataOutputConnectionOrientation = .portrait
        } else {
            VideoDataOutputConnectionOrientation = .portrait
        }
    }

    /**
     Updates the video ration when the device changes orientation.
     */
    private func updateVideoRation() {
        if (!isStreaming) {
            let oWidth = self.StreamWidth
            let oHeight = self.StreamHeight
            if (UIDevice.current.orientation.isLandscape) {
                self.streamWidth = oWidth > oHeight ? oWidth : oHeight
                self.streamHeight = oWidth <= oHeight ? oWidth : oHeight
            } else {
                self.streamWidth = oWidth < oHeight ? oWidth : oHeight
                self.streamHeight = oWidth >= oHeight ? oWidth : oHeight
            }
        }
    }

    /**
     Updates the screen/preview settings when the device changes orientation.
     */
    func updateOrientation() {
        if (self.streamButton != nil && !self.isStreaming) {
            updateVideoOrientation()
            updateDepthVideoOrientation()
            updatePreviewOrientation()
            updateVideoRation()
            if UIDevice.current.orientation.isLandscape {
                streamButton.frame = CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 100), width: 160, height: 50)
                self.takeLocalPhotoButton.frame = CGRect(x: (self.view.frame.size.width + 180) / 2, y: (self.view.frame.size.height - 100), width: 160, height: 50)
                self.takePhotoButton.frame = CGRect(x: (self.view.frame.size.width - 500) / 2, y: (self.view.frame.size.height - 100), width: 160, height: 50)


                settingsButton.frame = CGRect(x: (self.view.frame.size.width - 25 - marginForButtons), y: marginForButtons, width: 25, height: 25)
            } else if UIDevice.current.orientation.isPortrait {
                streamButton.frame = CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 100), width: 160, height: 50)
                self.takeLocalPhotoButton.frame = CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 204), width: 160, height: 50)
                self.takePhotoButton.frame = CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 152), width: 160, height: 50)
                settingsButton.frame = CGRect(x: (self.view.frame.size.width - 25 - marginForButtons), y: marginForButtons, width: 25, height: 25)
            }
        }
    }

    /**
     Updates the preview orientation when the device changes orientation.
     */
    func updatePreviewOrientation(){
        let allSublayers = self.view.layer.sublayers
        for currentLayer in allSublayers! {
            let preview = currentLayer as? AVCaptureVideoPreviewLayer
            if  preview != nil {
                preview?.videoGravity = AVLayerVideoGravity.resizeAspectFill
                if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
                    preview?.connection?.videoOrientation = .landscapeRight// TODO why
                } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
                    preview?.connection?.videoOrientation = .landscapeLeft // TODO why
                } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
                    preview?.connection?.videoOrientation = .portrait
                } else {
                    preview?.connection?.videoOrientation = .portrait
                }
                preview?.frame = self.view.bounds
            }
        }
    }

    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: .video, position: .unspecified)
    private let sessionQueue = DispatchQueue(label: "MyQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let dataOutputQueue = DispatchQueue(label: "video depth data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let captureDataOutputSynchronizerQueue = DispatchQueue(label: "Queue captureDataOutputSynchronizer", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let errormessageQueue = DispatchQueue(label: "error")

    /// Displays the current streaming status on the screen
    private var statuslable: UILabel!

    /// Displays the error streaming status on the screen if the connection is lost, otherwise it is hidden
    private var errorlable: UILabel!

    /// Provides the possibillity to open the settings
    private var settingsButton: UIButton!

    /// is true if the connection is lost
    private var showErrorField = false

    /**
        Called after the controller's view is loaded into memory.
        This method is called after the view controller has loaded its view hierarchy into memory. This method is called regardless of whether the view hierarchy was loaded from a nib file or created programmatically in the loadView() method. You usually override this method to perform additional initialization on views that were loaded from nib files.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        var myDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "streamingConfiguration", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }

        //TODO
        if let dict = myDict {
            if (self.endpointUrlString == nil){
                let epUS = UserDefaults.standard.object(forKey: "endpointUrlString")
                if (epUS == nil) {
                    self.endpointUrlString = dict.value(forKey: "endpointUrlString") as? String
                    UserDefaults.standard.set(self.endpointUrlString!, forKey: "endpointUrlString")
                } else {
                    //self.endpointUrlString = dict.value(forKey: "endpointUrlString") as? String
                    self.endpointUrlString = UserDefaults.standard.object(forKey: "endpointUrlString") as? String
                    print("epUS!")
                    print(epUS!)
                    print(self.endpointUrlString!)
                }
            }

            if (self.filtered == nil){
                let f = UserDefaults.standard.object(forKey: "filterDepth")
                if (f == nil) {
                    self.filtered = dict.value(forKey: "filterDepth") as? Bool

                    UserDefaults.standard.set(self.filtered!, forKey: "filterDepth")
                } else {
                    self.filtered = UserDefaults.standard.bool(forKey: "filterDepth")
                    print("f!")
                    print(f!)

                    print(dict.value(forKey: "filterDepth") as? Bool? as Any)
                }
            }

            if (self.streamWidth == nil){
                let sW = UserDefaults.standard.object(forKey: "streamWidth")
                if (sW == nil) {
                    self.streamWidth = dict.value(forKey: "streamWidth") as? Int
                    UserDefaults.standard.set(self.streamWidth!, forKey: "streamWidth")
                } else {
                    //self.streamWidth = dict.value(forKey: "streamWidth") as? Int
                    self.streamWidth = UserDefaults.standard.object(forKey: "streamWidth") as? Int

                    print("sW!")
                    print(sW!)
                    print(self.streamWidth!)
                }
            }

            if (self.streamHeight == nil){
                let sH = UserDefaults.standard.object(forKey: "streamHeight")
                if (sH == nil) {
                    self.streamHeight = dict.value(forKey: "streamHeight") as? Int
                    UserDefaults.standard.set(self.streamHeight!, forKey: "streamHeight")
                } else {
                    self.streamHeight = UserDefaults.standard.object(forKey: "streamHeight") as? Int
                    print("sH!")
                    print(sH!)
                    print(self.streamHeight!)
                }
            }

            if (self.sendVideoAllXSeconds == nil){
                // must be an integer
                let sVAXS = UserDefaults.standard.object(forKey: "streamingFrequency")
                if (sVAXS == nil) {
                    self.sendVideoAllXSeconds = dict.value(forKey: "streamingFrequency") as? Double
                    UserDefaults.standard.set(self.sendVideoAllXSeconds!, forKey: "streamingFrequency")
                } else {
                    self.sendVideoAllXSeconds = UserDefaults.standard.object(forKey: "streamingFrequency") as? Double
                    print("sVAXS!")
                    print(sVAXS!)
                    print(self.sendVideoAllXSeconds!)
                }
            }
            
            if (self.saveVideoPNG == nil){
                self.saveVideoPNG = (dict.value(forKey: "saveVideoPNG") as! Bool)
            }
            
            if (self.maxDisparity == nil){
                self.maxDisparity = (dict.value(forKey: "maxDisparity")! as! NSNumber).doubleValue
            }
            
            if (self.minDisparity == nil){
                self.minDisparity = (dict.value(forKey: "minDisparity")! as! NSNumber).doubleValue
            }
        }

        self.addObservers()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
        preview.addGestureRecognizer(tapGesture)

        do {
            // Clear Directories
            assert((self.endpointUrlString?.count)! > 0, "### You didn't provide your server endpoint URL ###")
            if let cachesDirectoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last as NSURL? {
                let contents = try FileManager.default.contentsOfDirectory(atPath: cachesDirectoryUrl.path!)
                for cacheFile in contents {
                    let fileToDelete = cachesDirectoryUrl.appendingPathComponent(cacheFile)
                    do {
                        try FileManager.default.removeItem(at: fileToDelete!)
                    } catch {
                        // TODO maybe there is a better way to handle this
                        print("File \(String(describing: fileToDelete)) couldn't be deleted: \(error)")
                        //fatalError(error.localizedDescription)
                    }
                }
            }

            if let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last as NSURL? {
                let contents = try FileManager.default.contentsOfDirectory(atPath: documentDirectoryUrl.path!)
                for documentFile in contents {
                    let fileToDelete = documentDirectoryUrl.appendingPathComponent(documentFile)
                    do {
                        try FileManager.default.removeItem(at: fileToDelete!)
                    } catch {
                        // TODO maybe there is a better way to handle this
                        print("File \(String(describing: fileToDelete)) couldn't be deleted: \(error)")
                    }
                }
            }

            ffmpegWrapper = FFmpegWrapper()
            // send all x seconds to server
            //maxTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(ViewController.timer(myTimer:)), userInfo: nil, repeats: false) // TODO change to true
            currentIndexVideo = 0
            currentIndexDepthBinary = 0

            session = AVCaptureSession()
            session.sessionPreset = .photo // TODO hier anpassen
            device = videoDeviceDiscoverySession.devices.first // only one device

            if device.isFocusModeSupported(.continuousAutoFocus) {
                try! device.lockForConfiguration()
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            }

            input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Could not add video camera to the session")
                return
            }

            let preview = AVCaptureVideoPreviewLayer(session:session)
            self.view.layer.addSublayer(preview)

            // Add Stream Video Button
            self.streamButton = UIButton(frame: CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 100), width: 160, height: 50))
            self.streamButton.backgroundColor = .black
            self.streamButton.setTitle("Stream Video", for: .normal)
            self.streamButton.addTarget(self, action:#selector(startstopstreaming(sender:)), for: .touchUpInside)
            self.view.addSubview(self.streamButton)

            // Add Take Photo Button
            self.takePhotoButton = UIButton(frame: CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 152), width: 160, height: 50))
            self.takePhotoButton.backgroundColor = .black
            self.takePhotoButton.setTitle("Stream Photo", for: .normal)
            self.takePhotoButton.addTarget(self, action:#selector(streamPhoto(sender:)), for: .touchUpInside)
            self.view.addSubview(self.takePhotoButton)

            // Add Take Photo Button
            self.takeLocalPhotoButton = UIButton(frame: CGRect(x: (self.view.frame.size.width - 160) / 2, y: (self.view.frame.size.height - 204), width: 160, height: 50))
            self.takeLocalPhotoButton.backgroundColor = .black
            self.takeLocalPhotoButton.setTitle("Take Photo", for: .normal)
            self.takeLocalPhotoButton.addTarget(self, action:#selector(takePhoto(sender:)), for: .touchUpInside)
            self.view.addSubview(self.takeLocalPhotoButton)


            // Add Settings Button
            settingsButton = UIButton(frame: CGRect(x: (self.view.frame.size.width - 25-10), y: 10, width: 25, height: 25))
            if UIImage(named: "setting.png") != nil {
                settingsButton.setImage(UIImage(named: "setting.png"), for: .normal)
            } else {
                settingsButton.setTitle("Go to Settings", for: .normal)
                settingsButton.backgroundColor = .black
            }
            //
            settingsButton.addTarget(self, action:#selector(openSettingsButtonPressed(sender:)), for: .touchUpInside)
            self.view.addSubview(settingsButton)

            statuslable = UILabel(frame: CGRect(x: marginForButtons, y: marginForButtons, width: 170, height: 30))
            statuslable.text = "Not Recording"
            statuslable.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.2)
            self.view.addSubview(statuslable)

            errorlable = UILabel(frame: CGRect(x: marginForButtons, y: marginForButtons+40, width: 300, height: 150))
            errorlable.isHidden = true
            errorlable.textColor = .red
            errorlable.numberOfLines = 0;
            errorlable.text = "No Connection"
            errorlable.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.2)
            self.view.addSubview(errorlable)

            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)] // TODO here added
                videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                // TODO fixiert auf porrai modus
                let videoConnection = videoDataOutput.connection(with: .video)
               //  /*
                if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
                    videoConnection?.videoOrientation = .landscapeLeft
                    currentvideoConnectionOrientation = .landscapeLeft
                } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight{
                    videoConnection?.videoOrientation = .landscapeRight
                    currentvideoConnectionOrientation = .landscapeRight
                } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
                    videoConnection?.videoOrientation = .portrait
                    currentvideoConnectionOrientation = .portrait
                } else {
                    videoConnection?.videoOrientation = .portrait
                    currentvideoConnectionOrientation = .portrait
                } // */
            } else {
                print("Could not add depth video output to the session")
                return
            }

            if session.canAddOutput(depthDataOutput) {
                session.addOutput(depthDataOutput)
                depthDataOutput.setDelegate(self, callbackQueue: sessionQueue)
                depthDataOutput.isFilteringEnabled = filtered! // TODO edit here
                let depthConnection = depthDataOutput.connection(with: .depthData)
                if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
                    depthConnection?.videoOrientation = .landscapeRight
                    currentDepthConnectionOrientation = .landscapeRight
                } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight{
                    depthConnection?.videoOrientation = .landscapeLeft
                    currentDepthConnectionOrientation = .landscapeLeft
                } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
                    depthConnection?.videoOrientation = .portrait
                    currentDepthConnectionOrientation = .portrait
                } else {
                    depthConnection?.videoOrientation = .portrait
                    currentDepthConnectionOrientation = .portrait
                }
            } else {
                print("Could not add depth data output to the session only streams Video Data now")
            }
            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Add photo output.
            if session.canAddOutput(stillImageOutput) {
                session.addOutput(stillImageOutput)
                stillImageOutput.isHighResolutionCaptureEnabled = true
                stillImageOutput.isLivePhotoCaptureEnabled = false
                stillImageOutput.isDepthDataDeliveryEnabled = true
                if #available(iOS 12.0, *) { stillImageOutput.isPortraitEffectsMatteDeliveryEnabled = false }
            } else {
                print("Could not add photo output to the session")
            }
            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [self.videoDataOutput, self.depthDataOutput])
            outputSynchronizer!.setDelegate(self, queue: sessionQueue)

            if let frameDuration = device.activeDepthDataFormat?.videoSupportedFrameRateRanges.first?.minFrameDuration {
                do {
                    try device.lockForConfiguration()
                    device.activeVideoMinFrameDuration = frameDuration // setting FPS
                    device.unlockForConfiguration()
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
            updateOrientation()
            // session.commitConfiguration() // TODO do we need this line

            session.startRunning()

            print("Initialization finished, ready for streaming...")

        } catch let error {
            // TODO make nicer
            print("ERROR: hier \(error)")
        }
    }

    /**
     Disables Autorotate for this Storyboard
     */
    open override var shouldAutorotate: Bool {
        get {
            return !isStreaming
        }
    }
    //

    /**
     takes photo and streams it to the server
     */
    @IBAction func streamPhoto(sender: UIButton!) {
        print("Button tapped")
        if !isStreaming {
            capturePhoto = true
            streamButton.isHidden = true
            startRecording()
        }
    }

    /**
     takes photo and streams it to the server
     */
    @IBAction func takePhoto(sender: UIButton!) {
        print("Button tapped")

        //* /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /*
         Retrieve the video preview layer's video orientation on the main queue before
         entering the session queue. We do this to ensure UI elements are accessed on
         the main thread and session configuration is done on the session queue.
         */

        sessionQueue.async {
            //let photoOutputConnection = self.stillImageOutput.connection(with: .video)

            var stillImageOutputSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            if let rawFormat = self.stillImageOutput.availableRawPhotoPixelFormatTypes.first {
                stillImageOutputSettings = AVCapturePhotoSettings(rawPixelFormatType: OSType(rawFormat))
            }
            //stillImageOutputSettings.flashMode = AVCaptureDevice.FlashMode.on //TODO change
            stillImageOutputSettings.isDepthDataDeliveryEnabled = true
            stillImageOutputSettings.embedsDepthDataInPhoto = true
            stillImageOutputSettings.isHighResolutionPhotoEnabled = true
            if !stillImageOutputSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                print(stillImageOutputSettings.__availablePreviewPhotoPixelFormatTypes.first!)
                stillImageOutputSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: stillImageOutputSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            }

            stillImageOutputSettings.isDepthDataDeliveryEnabled = true
            //self.stillImageOutput.capturePhoto(with: self.stillImageOutputSettings, delegate: self)
            self.stillImageOutput.capturePhoto(with: stillImageOutputSettings, delegate: self)
        }
    }

    /**
        Starts/Stops the streaming of the app
     */
    @IBAction func startstopstreaming(sender: UIButton!) {
        if isStreaming {
            stopRecording()
            takePhotoButton.isHidden = false
            takeLocalPhotoButton.isHidden = false
            streamButton.setTitle("Stream to Server", for: .normal)
            showErrorField = false
            errorStatusLable(newText: "")
        } else {
            capturePhoto = false
            startRecording()
            takePhotoButton.isHidden = true
            takeLocalPhotoButton.isHidden = true
            streamButton.setTitle("Stop streaming", for: .normal)
        }
    }

    /**
     Opens Settings Story board if there is no streaming
     */
    @IBAction func openSettingsButtonPressed(sender: UIButton!) {
        if !isStreaming {
            self.performSegue(withIdentifier: "SegueOpenSettings", sender: nil)
        }
    }

    /**
     Starts streaming **RGB** / **Deapth** - Data to the specified URL
     */
    func startRecording() {
        settingsButton.isHidden = true
        do {
            let toCache = false
            var cacheDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last as NSURL?

            if (toCache) {
                cacheDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last as NSURL?
            }

            currentIndexVideo = 0
            currentIndexDepthBinary = 0

            activeVideoWritingIndex = 0
            activeVideoStreamingIndex = 0


            if avAssetWriterVideo.count == 0 {
                for index in 0...1 {
                    let saveVideoFileURL = cacheDirectoryURL?.appendingPathComponent("captureVideo\(currentIndexVideo+index).m4v")
                    if FileManager.default.fileExists(atPath: saveVideoFileURL!.path) {
                        try FileManager.default.removeItem(at: saveVideoFileURL!)
                    }
                    avAssetWriterVideo.append(try AVAssetWriter(outputURL: saveVideoFileURL!, fileType: AVFileType.m4v))
                    avAssetWriterVideoInput.append(AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey: self.StreamWidth, AVVideoHeightKey: self.StreamHeight]))
                }
            } else {
                for index in 0...1 {
                    let saveVideoFileURL = cacheDirectoryURL?.appendingPathComponent("captureVideo\(currentIndexVideo+index).m4v")
                    if FileManager.default.fileExists(atPath: saveVideoFileURL!.path) {
                        try FileManager.default.removeItem(at: saveVideoFileURL!)
                    }
                    avAssetWriterVideo[index] = try AVAssetWriter(outputURL: saveVideoFileURL!, fileType: AVFileType.m4v)
                    avAssetWriterVideoInput[index] = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey: self.StreamWidth, AVVideoHeightKey: self.StreamHeight])
                }
            }

            for index in 0...1 {
                avAssetWriterVideoInput[index]!.expectsMediaDataInRealTime = true
                if avAssetWriterVideo[index]!.canAdd(avAssetWriterVideoInput[index]!) {
                    avAssetWriterVideo[index]!.add(avAssetWriterVideoInput[index]!)
                }
                avAssetWriterVideo[index]!.movieFragmentInterval = CMTimeMakeWithSeconds(sendVideoAllXSeconds!, preferredTimescale: 600)
                avAssetWriterVideo[index]!.startWriting()
                avAssetWriterVideo[index]!.startSession(atSourceTime: CMTimeMakeWithSeconds(sendVideoAllXSeconds!, preferredTimescale: 600))
            }


            
            
            
            if binaryDepthData.count == 0 {
                for _ in 0...1 {
                    binaryDepthData.append(Data())
                }
            } else {
                for index in 0...1 {
                    binaryDepthData[index] = Data()
                }
            }

            countFramesinStream = 0
            countSecondsinStream = 0


            isStreaming = true
            print("Start streaming...")

            maxTimer = Timer.scheduledTimer(timeInterval: sendVideoAllXSeconds!, target: self, selector: #selector(ViewController.timer(myTimer:)), userInfo: nil, repeats: true) // TODO change to true

        } catch let error {
            // TODO make nicer
            print("Error: \(error)")
            fatalError(error.localizedDescription)
        }
    }

    /**
     Stopps streaming **RBG** / **Deapth** - Data
     */
    func stopRecording() {
        isStreaming = false
        settingsButton.isHidden = false
        updateStatusLable(newText: "not recording")
        maxTimer?.invalidate()
        maxTimer = nil
        takePhotoButton.isHidden = false
        streamButton.isHidden = false
        streamButton.setTitle("Stream to Server", for: .normal)
    }


    // MARK: - Synchronized Data Output Delegate
    /**
     Provides a collection of synchronized capture data to the delegate.
     Use the data collection's synchronizedData(for:) method (or equivalent subscript(_:) operator) to retrieve the captured data corresponding to each capture output.
     - Parameter synchronizer: The synchronizer object delivering synchronized data.
     - Parameter synchronizedDataCollection: A collection of data samples, one for each capture output governed by the data output synchronizer for which capture data is ready.
     */
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        if(!isStreaming) {
            return
        }

        avAssetWriterSyncronizedQueue.sync {
            if(!finishedWritingVideo) {
                print("Skip frame")
                return
            }
            
            //print("Write frame")

            if(capturePhoto && countFramesinStream > 0) {
                return
            }

            if let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData {
                if !syncedVideoData.sampleBufferWasDropped {
                    let videoSampleBuffer = syncedVideoData.sampleBuffer
                    
                    CMSampleBufferGetSampleTimingInfo(videoSampleBuffer, at: 0, timingInfoOut: &depthTimingInfo)
                    //print("Write Frame timestamp: \(depthTimingInfo.presentationTimeStamp.value)")//
                    
                    processVideo(sampleBuffer: videoSampleBuffer)
                }
            }
            if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
                if !syncedDepthData.depthDataWasDropped {
                    let depthData = syncedDepthData.depthData
                    
                    
                    
                    
                    processDepth(depthData: depthData)
                }
            }
            countFramesinStream = countFramesinStream + 1

        }
    }

    // MARK: - Video Data Output Delegate
    /**
     Notifies the delegate that a video frame was discarded.
     Delegates receive this message whenever a late video frame is dropped. This method is called once for each dropped frame. It is called on the dispatch queue specified by the output’s sampleBufferCallbackQueue property.
     The sampleBuffer will contain a kCMSampleBufferAttachmentKey_DroppedFrameReason attachment that details why the frame was dropped. The frame may be dropped because it was late (kCMSampleBufferDroppedFrameReason_FrameWasLate), typically caused by the client’s processing taking too long. It can also be dropped because the module providing frames is out of buffers (kCMSampleBufferDroppedFrameReason_OutOfBuffers). Frames can also be dropped due to a discontinuity (kCMSampleBufferDroppedFrameReason_Discontinuity), if the module providing sample buffers has experienced a discontinuity, and an unknown number of frames have been lost. This condition is typically caused by the system being too busy.
     Because this method is called on the same dispatch queue that is responsible for outputting video frames, it must be efficient to prevent further capture performance problems, such as additional dropped video frames.
     - Parameter captureOutput: The capture output object.
     - Parameter sampleBuffer: A CMSampleBuffer object containing information about the dropped frame, such as its format and presentation time.. This sample buffer contains none of the original video data.
     - Parameter connection: The connection from which the video was received.
     */
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }


    /**
     Notifies the delegate that a new video frame was written.
     Delegates receive this message whenever the output captures and outputs a new video frame, decoding or re-encoding it as specified by its videoSettings property. Delegates can use the provided video frame in conjunction with other APIs for further processing.
     This method is called on the dispatch queue specified by the output’s sampleBufferCallbackQueue property. It is called periodically, so it must be efficient to prevent capture performance problems, including dropped frames.
     If you need to reference the CMSampleBuffer object outside of the scope of this method, you must CFRetain it and then CFRelease it when you are finished with it.
     To maintain optimal performance, some sample buffers directly reference pools of memory that may need to be reused by the device system and other capture inputs. This is frequently the case for uncompressed device native capture where memory blocks are copied as little as possible. If multiple sample buffers reference such pools of memory for too long, inputs will no longer be able to copy new samples into memory and those samples will be dropped.
     If your application is causing samples to be dropped by retaining the provided CMSampleBuffer objects for too long, but it needs access to the sample data for a long period of time, consider copying the data into a new buffer and then releasing the sample buffer (if it was previously retained) so that the memory it references can be reused.
     - Parameter captureOutput: The capture output object.
     - Parameter sampleBuffer: A CMSampleBuffer object containing the video frame data and additional information about the frame, such as its format and presentation time.
     - Parameter connection: The connection from which the video was received.
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        //print(#function)
        //processVideo(sampleBuffer!: CMSampleBuffer) // TODO delete repetitive code
        print("captureOutput")

        updateVideoOrientation()

        //print("capture Output; nicht process Video")
        if avAssetWriterVideoInput[activeVideoWritingIndex]!.isReadyForMoreMediaData == true {
            let successful = avAssetWriterVideoInput[activeVideoWritingIndex]!.append(sampleBuffer)
            if(successful == false) {
                print("CaptureOutput appending failed due to busy encoder. Please stop streaming and retry. Error message: \(avAssetWriterVideo[activeVideoWritingIndex]!.error!)")
                showErrorField = true
                errorStatusLable(newText: "CaptureOutput appending failed due to busy encoder. Please stop streaming and retry. Error message: \(avAssetWriterVideo[activeVideoWritingIndex]!.error!)")
                return
            }
            let status = avAssetWriterVideo[activeVideoWritingIndex]!.status
            // let error = avAssetWriter.error
            switch status {
            case .unknown:
                updateStatusLable(newText: "unknown")
            case .writing:
                updateStatusLable(newText: "writing")
            case .completed:
                updateStatusLable(newText: "completed")
            case .failed:
                updateStatusLable(newText: "failed")
            case .cancelled:
                updateStatusLable(newText: "cancelled")
                //default:
                //    updateStatusLable(newText: "DEFAULT")
            }
        }
    }

    // MARK: - Depth Data Output Delegate
    /**
     Informs the delegate that captured depth data was not processed.
     The capture output calls this method once for each dropped depth data whenever data is dropped. The object in the depthData parameter is an empty shell, containing no actual depth data backing pixel buffer
     The capture output calls this method on the dispatch queue specified by its delegateCallbackQueue property. Because this method executes on the same dispatch queue that outputs depth data, your implementation must be efficient to prevent further capture performance problems such as additional drops.
     - Parameter output: The depth data output providing data.
     - Parameter depthData: A depth data object containing information about the dropped data, such as its data type. Because this depth data was not captured or processed, its depthDataMap property is empty.
     - Parameter timestamp: The time at which the data was captured.
     - Parameter connection: The capture connection through which the data was captured.
     - Parameter reason: The reason depth data was dropped
     */
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {}
    /**
     Provides newly captured depth data to the delegate.
     The depth data output calls this method whenever it captures and outputs a new depth data object. This method is called on the dispatch queue specified by the output's delegateCallbackQueue property, and can be called frequently. Your implementation must process the depth data quickly in order to prevent dropped depth data.
     To maintain optimal performance, the capture pipeline may allocate AVDepthData pixel buffer maps from a finite memory pool. If you hold onto any AVDepthData objects for too long, capture inputs cannot copy new depth data into memory, resulting in dropped depth data. If your application is causing depth data drops by holding on to provided depth data objects for too long, consider copying the pixel buffer map data into a new pixel buffer so that the AVDepthData backing memory can be reused more quickly.
     - Parameter output: The depth data output providing data.
     - Parameter depthData: A depth data object containing the captured per-pixel depth data.
     - Parameter timestamp: The time at which the data was captured.
     - Parameter connection: The capture connection through which the data was captured.
     */
    func depthDataOutput(_ depthDataOutput: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {}

    // MARK: - processing the captured data
    /**
     Processes the captured Video Data
     - Parameter sampleBuffer: Captured sampleBuffer, which will be processed
     */
    func processVideo(sampleBuffer: CMSampleBuffer) {
        
        if avAssetWriterVideoInput[activeVideoWritingIndex]!.isReadyForMoreMediaData == true {
            var successful = true;
            var countRepeat = 0
            repeat {
                successful = avAssetWriterVideoInput[activeVideoWritingIndex]!.append(sampleBuffer)
                if(!successful && avAssetWriterVideo[activeVideoWritingIndex]!.error != nil && countRepeat == 0) {
                    print("Video appending failed. Error: \(String(describing: avAssetWriterVideo[activeVideoWritingIndex]!.error))")
                    showErrorField = true
                    errorStatusLable(newText: "Video appending failed. Error message: \(String(describing: avAssetWriterVideo[activeVideoWritingIndex]!.error))")
                }
                if (!successful) {
                    countRepeat = countRepeat + 1
                    usleep(1000)
                }
            } while(!successful && (avAssetWriterVideo[activeVideoWritingIndex]!.error == nil || countRepeat <= 10))
            if(!successful) {
                stopRecording()
                return
            }

            let status = avAssetWriterVideo[activeVideoWritingIndex]!.status
            switch status {
                case .unknown:
                    updateStatusLable(newText: "unknown")
                case .writing:
                    updateStatusLable(newText: "writing")
                case .completed:
                    updateStatusLable(newText: "completed")
                case .failed:
                    print("failed activeVideoWritingIndex=\(activeVideoWritingIndex)")
                    print(avAssetWriterVideo[activeVideoWritingIndex]!.outputURL)
                    updateStatusLable(newText: "failed")
                case .cancelled:
                    updateStatusLable(newText: "cancelled")
                //default:
                //    updateStatusLable(newText: "DEFAULT")
            }

        } else {
            print("Cannot write Video because is streaming")
            print("avAssetWriterVideoInput[activeVideoWritingIndex=\(activeVideoWritingIndex)].isReadyForMoreMediaData = \(avAssetWriterVideoInput[activeVideoWritingIndex]!.isReadyForMoreMediaData)")
            print("avAssetWriterVideoInput[activeVideoStreamingIndex=\(activeVideoStreamingIndex)].isReadyForMoreMediaData = \(avAssetWriterVideoInput[activeVideoStreamingIndex]!.isReadyForMoreMediaData)")
        }
    }

    /**
     Updates the Status Lable
     - Author: Simon Reisinger
     - Parameter newText: The new Text, which will be displayed by the label
     */
    func updateStatusLable(newText: String) {
        DispatchQueue.main.async {
            self.statuslable.text = newText
            self.statuslable.reloadInputViews()
        }
    }

    /**
     Updates the Error Label
     - Author: Simon Reisinger
     - Parameter newText: The new Text, which will be displayed by the label
     */
    func errorStatusLable(newText: String) {
        if (showErrorField) {
            DispatchQueue.main.async {
                self.errorlable.textColor = .red
                self.errorlable.text = newText
                self.errorlable.isHidden = false
            }
        } else {
            DispatchQueue.main.async {
                self.errorlable.isHidden = true
                self.errorlable.textColor = .black
                self.errorlable.text = newText
            }
        }
    }


    /**
     Processes the captured Depth Data
     - Parameter depthData: Captured depth data, which will be processed
     */
    func processDepth(depthData: AVDepthData) {
        //print(#function)
        
        let widthData = CVPixelBufferGetWidth(depthData.depthDataMap)
        let heightData = CVPixelBufferGetHeight(depthData.depthDataMap)
        
        
        let depthDataFloat32 = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32);
        
        let pixelBufferFloat32 = depthDataFloat32.depthDataMap
        
        CVPixelBufferLockBaseAddress(pixelBufferFloat32, [])
        
        let baseAddressFloat32 = CVPixelBufferGetBaseAddress(pixelBufferFloat32)
        
        let float32Buffer = unsafeBitCast(baseAddressFloat32, to: UnsafeMutablePointer<Float>.self)
        
        
        //let start = DispatchTime.now()
        
        var byteData = [UInt8]()
        
        let factor : Float32 = Float32(255.0 / (self.maxDisparity! - self.minDisparity!))
        //var count : UInt8 = 0
        //var i : Int = 0
        let width : Int = CVPixelBufferGetWidth(depthData.depthDataMap)
        let height : Int = CVPixelBufferGetHeight(depthData.depthDataMap)
        //let last = (CVPixelBufferGetHeight(depthData.depthDataMap)-1) * (CVPixelBufferGetWidth(depthData.depthDataMap)-1)
        //while (i <= last) {
        for r in 0...height-1 {
            for c in 0...width-1 {
                
                var f = (float32Buffer[r * widthData + c] - Float32(self.minDisparity!)) * factor
                if (f < Float32(UInt8.min)) {
                    f = 0;
                }
                if (f > Float32(UInt8.max)) {
                    f = 255;
                }
                var i : UInt8 = UInt8(f)
                if (i > 255) {
                    i = 255
                }
                byteData.append(i)
            }
        }
        
        
        let wData = Data(bytes: byteData, count: widthData * heightData * MemoryLayout<UInt8>.stride)
        
        self.binaryDepthData[self.activeDepthBinaryWritingIndex].append(wData)
        
        
        
        CVPixelBufferUnlockBaseAddress(pixelBufferFloat32, [])
        
        
        
        if (self.saveVideoPNG!) {
        
            self.videoDepthConverter.reset()
            
            if !videoDepthConverter.isPrepared {
                /*
                 outputRetainedBufferCountHint is the number of pixel buffers we expect to hold on to from the renderer. This value informs the renderer
                 how to size its buffer pool and how many pixel buffers to preallocate. Allow 2 frames of latency to cover the dispatch_async call.
                 */
                var depthFormatDescription: CMFormatDescription?
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: depthData.depthDataMap, formatDescriptionOut: &depthFormatDescription)
                videoDepthConverter.prepare(with: depthFormatDescription!, outputRetainedBufferCountHint: 2)
                videoDepthConverter.setDepthEncoding(value: true)
            } else {
                print("Not prepared")
                return
            }
            
            guard let depthPixelBuffer = videoDepthConverter.render(pixelBuffer: depthData.depthDataMap) else {
                print("Unable to process depth")
                return
            }
            
            
            
            let start = DispatchTime.now() // <<<<<<<<<< Start time
            
            // get the current date and time
            let currentDateTime = Date()
            
            // get the user's calendar
            let userCalendar = Calendar.current
            
            // choose which date and time components are needed
            let requestedComponents: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            
            // get the components
            let dateTimeComponents = userCalendar.dateComponents(requestedComponents, from: currentDateTime)
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // depth
            var i2: CGImage?
            VTCreateCGImageFromCVPixelBuffer(depthPixelBuffer, options: nil, imageOut: &i2)
            let i3 = UIImage(cgImage: i2!)
            let i4 = i3.pngData()
            
            let imagedepthURL = documentsURL.appendingPathComponent("I_c\(globalFrameCounter)_f\(countFramesinStream)_\(dateTimeComponents.year!)_\(dateTimeComponents.month!)_\(dateTimeComponents.day!)_\(dateTimeComponents.hour!)_\(dateTimeComponents.minute!)_\(dateTimeComponents.second!)_depth.png")
            
            
            do { try i4!.write(to: imagedepthURL) } catch let error as NSError { print(error) }
            
            let end = DispatchTime.now()   // <<<<<<<<<<   end time
            self.binaryDepthData[self.activeDepthBinaryWritingIndex].append(wData)
            
            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
            let timeInterval = Double(nanoTime) / 1_000_000 // Technically could overflow for long running tests
            
            print("Time to save png: \(timeInterval) ms")
        
        }
        
        globalFrameCounter = globalFrameCounter + 1
        
    }
    
    func recreateAvAssetWriterVideo() {
        if (self.showErrorField) {
            self.showErrorField = false
            self.errorStatusLable(newText: "Connection Works")
        }
        self.currentIndexVideo = self.currentIndexVideo + 1
        let cacheDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last as NSURL?
        let saveFileURL = cacheDirectoryURL?.appendingPathComponent("captureVideo\(self.currentIndexVideo+1).m4v")
        if FileManager.default.fileExists(atPath: saveFileURL!.path) {
            do {
                try FileManager.default.removeItem(at: saveFileURL!)
                //print("Removed: \(String(describing: saveFileURL))")
            } catch let error {
                // TODO make nicer
                print("Remove error: \(error)")
            }
        }
        
        self.avAssetWriterSyncronizedQueue.sync {
            self.avAssetWriterVideoInput[self.activeVideoStreamingIndex] = nil
            self.avAssetWriterVideo[self.activeVideoStreamingIndex] = nil
            do {
                self.avAssetWriterVideo[self.activeVideoStreamingIndex] = try AVAssetWriter(outputURL: saveFileURL!, fileType: AVFileType.m4v)
            } catch let error {
                print("Open error: \(error)")
            }
            
            self.avAssetWriterVideoInput[self.activeVideoStreamingIndex] = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey: self.streamWidth!, AVVideoHeightKey: self.streamHeight!])
            self.avAssetWriterVideoInput[self.activeVideoStreamingIndex]!.expectsMediaDataInRealTime = true
            self.avAssetWriterVideo[self.activeVideoStreamingIndex]!.add(self.avAssetWriterVideoInput[self.activeVideoStreamingIndex]!)
            self.avAssetWriterVideo[self.activeVideoStreamingIndex]!.movieFragmentInterval = CMTimeMakeWithSeconds(self.sendVideoAllXSeconds!, preferredTimescale: 600)
            
            self.avAssetWriterVideo[self.activeVideoStreamingIndex]!.startWriting()
            self.avAssetWriterVideo[self.activeVideoStreamingIndex]!.startSession(atSourceTime: CMTimeMakeWithSeconds(self.sendVideoAllXSeconds!, preferredTimescale: 600))
            
            self.activeVideoStreamingIndex = 1 - self.activeVideoStreamingIndex
            
        }
    }

    // MARK: - timer
    /**
     Brodcasts the collected **RGB** / **Depth** Videodata to the server when triggered
     - Parameter myTimer: current time
     - Note: Based on [VideoLiveStreaming]{https://github.com/MerchV/VideoLiveStreaming}
     */
    @objc func timer(myTimer: Timer) {
        
        self.countSecondsinStream = self.countSecondsinStream + self.sendVideoAllXSeconds!
        
        if (1-self.activeVideoWritingIndex == self.activeVideoStreamingIndex || self.countFramesinStream == 0) {
            print("Not ready with streaming last one, waiting for next trigger")
            showErrorField = true
            errorStatusLable(newText: "Not ready with streaming last one, waiting for next trigger")
            
            print("activeVideoWritingIndex = \(self.activeVideoWritingIndex)")
            print("activeVideoStreamingIndex = \(self.activeVideoStreamingIndex)")
            print("countFramesinStream = \(self.countFramesinStream)")
            
            return
        }

        if(capturePhoto) {
            print("Sending image...")
        } else {
            print("Sending video part \(currentIndexVideo!)...")
        }

        if isStreaming {
            avAssetWriterSyncronizedQueue.sync {
                self.activeVideoWritingIndex = 1 - self.activeVideoWritingIndex
                self.activeDepthBinaryWritingIndex = 1 - self.activeDepthBinaryWritingIndex
                let countFramesinStreamCurrent : UInt8 = UInt8(self.countFramesinStream)
                let countSecondsinStreamCurrent : Double = self.countSecondsinStream
                self.countFramesinStream = 0
                self.countSecondsinStream = 0
                
                
                
                let queue = DispatchQueue.global(qos: .default)
                queue.async {
                    
                    print("Writing Byte Data")
                    
                    
                    var tsData = Data()
                    
                    var byteMetaData = [UInt8]()
                    byteMetaData.append(countFramesinStreamCurrent)
                    
                    
                    let sendVideoAllXMillisecondes : UInt16 = UInt16(countSecondsinStreamCurrent * 1000.0)
                    let sendVideoAllXMillisecondesMSB : UInt8 = UInt8(sendVideoAllXMillisecondes / 256)
                    byteMetaData.append(sendVideoAllXMillisecondesMSB)
                    let sendVideoAllXMillisecondesLSB : UInt8 = UInt8(sendVideoAllXMillisecondes % 256)
                    byteMetaData.append(sendVideoAllXMillisecondesLSB)
                    
                    
                    let wDataMetaData = Data(bytes: byteMetaData, count: byteMetaData.count * MemoryLayout<UInt8>.stride)
                    
                    tsData.append(wDataMetaData)
                        
                        
                    tsData.append(self.binaryDepthData[self.activeDepthBinaryStreamingIndex]) //try Data(contentsOf: saveFileURL!)
                    
                    
                    
                    
                    
                    let mediaType = self.capturePhoto ? "image" : "video"
                    
                    
                    let cacheDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last as NSURL?
                    let saveFileURL = cacheDirectoryURL?.appendingPathComponent("\(mediaType)Depth\(self.currentIndexDepthBinary!).binaryDepth")
                    
                    
                    
                    let start = DispatchTime.now()
                    var zipFilePath : URL!
                    do {
                        try tsData.write(to: saveFileURL!)
                        
                        zipFilePath = try Zip.quickZipFiles([saveFileURL!], fileName: "\(mediaType)Depth\(self.currentIndexDepthBinary!)") // Zip
                    }
                    catch {
                        print("Something went wrong")
                    }
                    let end = DispatchTime.now()
                    
                    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
                    let timeInterval = Double(nanoTime) / 1_000_000 // Technically could overflow for long running tests
                    
                    //print("Time to save and zip: \(timeInterval) ms")
                    
                    
                    
                    
                    let urlString = "\(self.endpointUrlString!)?filename=\(mediaType)Depth_\(self.currentIndexDepthBinary!).zip"
                    let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL)
                    request.httpMethod = "PUT"
                    do
                    {
                        
                        let zipData = try Data(contentsOf: zipFilePath)
                        
                        
                        print("Stream this data")
                        
                    
                        request.httpBody = zipData as Data
                        
                        //if nil != tsData {
                        URLSession.shared.uploadTask(with: request as URLRequest, from: (zipData as Data), completionHandler: { (responseData: Data?, response: URLResponse?, responseError: Error?) -> Void in
                        
                            print("sended")
                            if responseData != nil {
                                
                                let responseString = NSString(data: responseData!, encoding: String.Encoding.utf8.rawValue)
                                print("ResponseString \(String(describing: responseString))")
                                if responseString != nil {
                                    print(responseString!)
                                    if(responseString!.contains("405")) {
                                        self.showErrorField = true
                                        self.errorStatusLable(newText: "405 Method Not Allowed")
                                    } else if (!self.showErrorField){
                                        self.showErrorField = false
                                        self.errorStatusLable(newText: "")
                                    }
                                }
                                
                            }
                        
                            self.binaryDepthData[self.activeDepthBinaryStreamingIndex] = Data()
                        
                            self.activeDepthBinaryStreamingIndex = 1 - self.activeDepthBinaryStreamingIndex
                        
                        }).resume()
                        
                        do {
                            try FileManager.default.removeItem(at: zipFilePath!)
                        } catch let error {
                            // TODO make nicer
                            print("Remove error: \(error)")
                        }
                        
                        
                    } catch let error {
                        print("Reading error: \(error)")
                    }
                    
                    self.currentIndexDepthBinary = self.currentIndexDepthBinary + 1
                }
                
                if avAssetWriterVideo[activeVideoStreamingIndex]!.status == .writing {
                    self.finishedWritingVideo = false
                    avAssetWriterVideoInput[activeVideoStreamingIndex]!.markAsFinished()
                    //print("avAssetWriterVideoInput[activeVideoStreamingIndex]!.markAsFinished()")
                
                    let outputUrl = avAssetWriterVideo[activeVideoStreamingIndex]!.outputURL
                    avAssetWriterVideo[activeVideoStreamingIndex]!.finishWriting { /*() -> Void in // */
                        //print("avAssetWriterVideo[activeVideoStreamingIndex]!.finishWriting")
                        self.finishedWritingVideo = true
                        let documentsDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last as NSURL?
                        let mediaType = self.capturePhoto ? "image" : "video"
                        let tsFileUrl = documentsDirectoryUrl?.appendingPathComponent("\(mediaType)Color\(self.currentIndexVideo!).ts")
                        self.ffmpegWrapper.convertInputPath(outputUrl.path, outputPath: tsFileUrl?.path, options: nil, progressBlock: { (a: UInt, b: UInt64, c: UInt64) -> Void in
                            //print("a: \(a), \(b), \(c)")
                        }, completionBlock: { (succeeded: Bool, b: Error?) -> Void in
                            print("Bool: \(succeeded)\n Error: \(String(describing: b))")
                            if succeeded {
                                let queue = DispatchQueue.global(qos: .default)
                                queue.async {
                                    let mediaType = self.capturePhoto ? "image" : "video"
                                    let urlString = "\(self.endpointUrlString!)?filename=\(mediaType)Color\(self.currentIndexVideo!).ts"
                                    let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL)
                                    request.httpMethod = "PUT"
                                    let tsData = NSData(contentsOf: tsFileUrl!)
                                    
                                    
                                    request.httpBody = tsData! as Data
                                    if nil != tsData {
                                        URLSession.shared.uploadTask(with: request as URLRequest, from: (tsData! as Data), completionHandler: { (responseData: Data?, response: URLResponse?, responseError: Error?) -> Void in
                                            if responseData != nil {
                                                
                                                let responseString = NSString(data: responseData!, encoding: String.Encoding.utf8.rawValue)
                                                if responseString != nil {
                                                    print(responseString!)
                                                    if(responseString!.contains("405")) {
                                                        self.showErrorField = true
                                                        self.errorStatusLable(newText: "405 Method Not Allowed")
                                                    } else if (!self.showErrorField){
                                                        self.showErrorField = false
                                                        self.errorStatusLable(newText: "")
                                                    }
                                                }
                                                
                                            }
                                            if responseError != nil {
                                                print("responseError")
                                                if (!self.showErrorField) {
                                                    self.showErrorField = true
                                                    let errorDiscrition = responseError?.localizedDescription
                                                    self.errorStatusLable(newText: "\(errorDiscrition!) No Connection")
                                                }
                                            } else {
                                                if (self.showErrorField) {
                                                    self.showErrorField = false
                                                    self.errorStatusLable(newText: "Connection Works")
                                                }
                                                
                                                self.recreateAvAssetWriterVideo()
                                                
                                                if(self.capturePhoto) {
                                                    print("Image Color sent sucessfully!")
                                                } else {
                                                    print("Video Color part \(self.currentIndexVideo-1) sent sucessfully!")
                                                }
                                            }
                                        }).resume()
                                    } else {
                                        print("No data")
                                    }
                                    
                                    
                                    do {
                                        try FileManager.default.removeItem(at: tsFileUrl!)
                                    } catch let error {
                                        // TODO make nicer
                                        print("Remove error: \(error)")
                                    }
                                    
                                }
                            }
                        })
                    }
                } else {
                    print("Error video not writing")
                    //recreateAvAssetWriterVideo()
                }
                
            }
        }
        if(capturePhoto) {
            stopRecording()
        }
    }

    /**
     Let's the user reset the autofocus manually, by touching on the screen
     - Parameter gesture:
     - Author: [Andrew Walz](https://github.com/Awalz/SwiftyCam)
     */
    @IBAction private func focusAndExposeTap(_ gesture: UITapGestureRecognizer) {
        print("FOCUS AND EXPOSE TAP")
        let tapPoint = gesture.location(in: preview)
        let screenSize = preview!.bounds.size

        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        showFocusarea(didFocusAtPoint: CGPoint(x: tapPoint.x, y: tapPoint.y))
        if let device = self.device {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                } else {
                    print("mode not supported")
                }
                print("After: \(device)")
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                device.unlockForConfiguration()
                //Call delegate function and pass in the location of the touch
            }
            catch {
                // just ignore
            }
        }
    }

    /**
     Displays a circle where the focus point was set. and removes it after some time
     - Parameter didFocusAtPoint: Position where focus was set
     - Author: [Andrew Walz](https://github.com/Awalz/SwiftyCam)
     */
    func showFocusarea(didFocusAtPoint point: CGPoint) {
        let focusView = UIImageView(image: #imageLiteral(resourceName: "focus"))
        focusView.center = point
        focusView.alpha = 0.0
        view.addSubview(focusView)

        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations: {
            focusView.alpha = 1.0
            focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }, completion: { (success) in
            UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseInOut, animations: {
                focusView.alpha = 0.0
                focusView.transform = CGAffineTransform(translationX: 0.6, y: 0.6)
            }, completion: { (success) in
                focusView.removeFromSuperview()
            })
        })
    }

    /**
     Notifies the view controller that a segue is about to be performed.
     The default implementation of this method does nothing. Subclasses override this method and use it to configure the new view controller prior to it being displayed. The segue object contains information about the transition, including references to both view controllers that are involved.
     Because segues can be triggered from multiple sources, you can use the information in the segue and sender parameters to disambiguate between different logical paths in your app. For example, if the segue originated from a table view, the sender parameter would identify the table view cell that the user tapped. You could then use that information to set the data on the destination view controller.
     - Parameter segue: The segue object containing information about the view controllers involved in the segue.
     - Parameter sender: The object that initiated the segue. You might use this parameter to perform different actions based on which control (or other object) initiated the segue.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "SegueOpenSettings") {
            let yourNextViewController = (segue.destination as! SettingsViewController)
            yourNextViewController.EndpointUrlString = endpointUrlString!
            yourNextViewController.FilterDepth = FilterDepth
            yourNextViewController.StreamWidth = streamWidth!
            yourNextViewController.StreamHeight = streamHeight!
            yourNextViewController.StreamingFrequency = StreamingFrequency
        }
    }

    // MARK: - Observer
    /**
     Creates Observer, which will trigger under certain circumstances
     - Author: [Apple](https://www.apple.com/)
     - Note: Based on a methode of [AVCamPhotoFilter](com.example.apple-samplecode.AVCamPhotoFilterN5MBV7GWSJ) from [Apple](https://www.apple.com/)
     */
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged), name: ProcessInfo.thermalStateDidChangeNotification,    object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    /**
     Triggers when the iPhone changes orientation. Changes orientation of the screen and the video
     */
    @objc func rotated() {
        self.updateOrientation()
    }

    /**
     Triggeres when the app enters background and stops recording
     - Author: [Apple](https://www.apple.com/)
     - Note: Based on a methode of [AVCamPhotoFilter](com.example.apple-samplecode.AVCamPhotoFilterN5MBV7GWSJ) from [Apple](https://www.apple.com/)
     - TODO: check if indexes should be reset ect.
     */
    @objc func didEnterBackground(notification: NSNotification) {
        // Free up resourcesor
        dataOutputQueue.async {
            self.currentDepthPixelBuffer = nil
            self.imageDepthConverter.reset()
            self.stopRecording()
        }
    }

    /**
     Triggeres when the thermel status changes an shows a notification
     - Author: [Apple](https://www.apple.com/)
     - Note: Based on a methode of [AVCamPhotoFilter](com.example.apple-samplecode.AVCamPhotoFilterN5MBV7GWSJ) from [Apple](https://www.apple.com/)
     */
    @objc func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }

    /**
     Shows an alert displaying the thermal status
     - Author: [Apple](https://www.apple.com/)
     - Note: Based on a methode of [AVCamPhotoFilter](com.example.apple-samplecode.AVCamPhotoFilterN5MBV7GWSJ) from [Apple](https://www.apple.com/)
     */
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }
            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
            let alertController = UIAlertController(title: "AVCamPhotoFilter", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // TODO add here
    }

    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // https://stackoverflow.com/questions/14531912/storing-images-locally-on-an-ios-device
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            // get the current date and time
            let currentDateTime = Date()

            // get the user's calendar
            let userCalendar = Calendar.current

            // choose which date and time components are needed
            let requestedComponents: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

            // get the components
            let dateTimeComponents = userCalendar.dateComponents(requestedComponents, from: currentDateTime)

            if let imageData = photo.fileDataRepresentation() {
                let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
                let auxiliaryData = CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource!, 0, kCGImageAuxiliaryDataTypeDisparity) as? [AnyHashable: Any]
                
                let depthData = try? AVDepthData(fromDictionaryRepresentation: auxiliaryData!)
                var depthDataMap = depthData?.depthDataMap
                
                self.imageDepthConverter.reset()
                
                if !imageDepthConverter.isPrepared {
                    var depthFormatDescription: CMFormatDescription?
                    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: depthDataMap!, formatDescriptionOut: &depthFormatDescription)
                    imageDepthConverter.prepare(with: depthFormatDescription!, outputRetainedBufferCountHint: 2)
                    imageDepthConverter.setDepthEncoding(value: false)
                } else {
                    print("Not prepared")
                    return
                }
                
                guard let depthPixelBuffer = imageDepthConverter.render(pixelBuffer: depthDataMap!) else {
                    print("Unable to process depth")
                    return
                }
                
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

                
                // depth
                var i2: CGImage?
                VTCreateCGImageFromCVPixelBuffer(depthPixelBuffer, options: nil, imageOut: &i2)
                let i3 = UIImage(cgImage: i2!)
                let i4 = i3.pngData()
                
                let imagedepthURL = documentsURL.appendingPathComponent("I\(dateTimeComponents.year!)_\(dateTimeComponents.month!)_\(dateTimeComponents.day!)_\(dateTimeComponents.hour!)_\(dateTimeComponents.minute!)_\(dateTimeComponents.second!)depth.png")
                do { try i4!.write(to: imagedepthURL) } catch let error as NSError { print(error) }

                
                //rgb
                let i3rgb = UIImage(data: imageData)
                let i4rgb = i3rgb!.pngData()
                
                let imagedepthURLrgb = documentsURL.appendingPathComponent("I\(dateTimeComponents.year!)_\(dateTimeComponents.month!)_\(dateTimeComponents.day!)_\(dateTimeComponents.hour!)_\(dateTimeComponents.minute!)_\(dateTimeComponents.second!)color.png")
                do { try i4rgb!.write(to: imagedepthURLrgb) } catch let error as NSError { print(error) }

                
                //heif
                let imageURL = documentsURL.appendingPathComponent("I\(dateTimeComponents.year!)_\(dateTimeComponents.month!)_\(dateTimeComponents.day!)_\(dateTimeComponents.hour!)_\(dateTimeComponents.minute!)_\(dateTimeComponents.second!)raw.heif")
                do { try imageData.write(to: imageURL) } catch let error as NSError { print(error) }
            }
        }
        // Portrait effects matte gets generated only if AVFoundation detects a face.
        if #available(iOS 12.0, *) {
            if var portraitEffectsMatte = photo.portraitEffectsMatte {
                if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
                }
            }
        }
    }
}
