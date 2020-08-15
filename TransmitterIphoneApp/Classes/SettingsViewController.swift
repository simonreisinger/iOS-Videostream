import UIKit

/**
 The setting View Controller controls the storyboard. The user can change some settings
 - Author: Simon Reisinger
 */
class SettingsViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    // MARK: - changeable setting values
    /// URL endpoint, where the **RGB** / **Deapth** -Videos are streamed to
    private var endpointUrlString: String!
    /// getter and setter Methode for endpointUrlString
    public var EndpointUrlString: String {
        get {
            return endpointUrlString
        }
        set {
            endpointUrlString = newValue
        }
    }
    
    /// Stores the selected option if the image is transmitted **filtered** or not
    private var filterDepth: Int!
    /// Provides setter and getter for the **filter**
    public var FilterDepth: Int {
        get {
            return filterDepth
        }
        set {
            filterDepth = newValue
        }
    }
    
    /// Stores **width** of the streamed video
    private var streamWidth: Int!
    /// Provides setter and getter for the **streamWidth**
    public var StreamWidth: Int {
        get {
            return streamWidth
        }
        set {
            streamWidth = newValue
        }
    }
    
    /// Stores **height** of the streamed video
    private var streamHeight: Int!
    /// Provides setter and getter for the **streamHeight**
    public var StreamHeight: Int {
        get {
            return streamHeight
        }
        set {
            streamHeight = newValue
        }
    }
    
    /// streamingFrequency of the streamed video
    private var streamingFrequency: Double!
    /// Provides setter and getter for the **streamingFrequency**
    public var StreamingFrequency: Double {
        get {
            return streamingFrequency
        }
        set {
            streamingFrequency = newValue
        }
    }

    // GUI Elements
    private var headlineLabel: UILabel!
    private var endpointUrlStringLabel: UILabel!
    private var endpointUrlStringTextField: UITextField!
    private var streamWidthLabel: UILabel!
    private var streamWidthTextField: UITextField!
    private var streamHeightLabel: UILabel!
    private var streamHeightTextField: UITextField!
    private var streamingFrequencyLabel: UILabel!
    private var streamingFrequencyTextField: UITextField!
    private var filteredLabel: UILabel!
    private var filter: UIPickerView!
    private let filterPossibilities = ["Yes","No"]
    
    private var saveButton: UIButton!
    private var returnButton: UIButton!
    private var changetoDefaultButton: UIButton!
    
    private var errorLabel: UILabel!
    
    private var allValuesAreValid = false

    // MARK: - GUI
    /**
     Called after the controller's view is loaded into memory.
     This method is called after the view controller has loaded its view hierarchy into memory. This method is called regardless of whether the view hierarchy was loaded from a nib file or created programmatically in the loadView() method. You usually override this method to perform additional initialization on views that were loaded from nib files.
     - Author: Simon Reisinger
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        
        let boarder = 20
        let screenSize = UIScreen.main.bounds
        let screenWidth = Int(screenSize.width)
        let screenHeight = Int(screenSize.height)
        
        // Create Title
        self.headlineLabel = UILabel(frame: CGRect(x: boarder, y: boarder, width: screenWidth-2*boarder, height: 40))
        self.headlineLabel.text = "Settings"
        self.headlineLabel.font = UIFont(name: self.headlineLabel.font.fontName, size: 30)
        self.view.addSubview(self.headlineLabel)
        
        // Create Lable
        self.endpointUrlStringLabel = UILabel(frame: CGRect(x: boarder, y: 70, width: screenWidth-2*boarder, height: 25))
        self.endpointUrlStringLabel.text = "Endpoint Url:"
        self.view.addSubview(endpointUrlStringLabel)
        
        // Create Textfield
        // TODO underline of the input window
        self.endpointUrlStringTextField = UITextField(frame: CGRect(x: boarder, y: 95, width: screenWidth-2*boarder, height: 25))
        self.endpointUrlStringTextField.text = endpointUrlString
        self.endpointUrlStringTextField.delegate = self
        let borderURL = CALayer()
        let widthURL = CGFloat(2.0)
        borderURL.borderColor = UIColor.darkGray.cgColor
        borderURL.frame = CGRect(x: 0, y: self.endpointUrlStringTextField.frame.size.height - widthURL, width:  self.endpointUrlStringTextField.frame.size.width, height: self.endpointUrlStringTextField.frame.size.height)
        
        borderURL.borderWidth = widthURL
        self.endpointUrlStringTextField.layer.addSublayer(borderURL)
        self.endpointUrlStringTextField.layer.masksToBounds = true
        self.view.addSubview(self.endpointUrlStringTextField)
        
        // Video Streaming Size
        let streamSizeWidth = screenWidth/2-Int(1.5*Float(boarder))
        // Create Lable stream Width
        self.streamWidthLabel = UILabel(frame: CGRect(x: boarder, y: 130, width: streamSizeWidth, height: 25))
        self.streamWidthLabel.text = "Video Width:"
        self.view.addSubview(self.streamWidthLabel)
        
        // Create Textfield
        self.streamWidthTextField = UITextField(frame: CGRect(x: boarder, y: 160, width: streamSizeWidth, height: 25))
        self.streamWidthTextField.text = String(self.streamWidth)
        self.streamWidthTextField.delegate = self
        
        let borderVideoWidth = CALayer()
        let widthVideoWidth = CGFloat(2.0)
        borderVideoWidth.borderColor = UIColor.darkGray.cgColor
        borderVideoWidth.frame = CGRect(x: 0, y: self.streamWidthTextField.frame.size.height - widthVideoWidth, width:  self.streamWidthTextField.frame.size.width, height: streamWidthTextField.frame.size.height)
        
        borderVideoWidth.borderWidth = widthVideoWidth
        self.streamWidthTextField.layer.addSublayer(borderVideoWidth)
        self.streamWidthTextField.layer.masksToBounds = true
        self.view.addSubview(streamWidthTextField)
        
        // Create Lable Stream Height
        self.streamHeightLabel = UILabel(frame: CGRect(x: boarder + screenWidth/2, y: 130, width: streamSizeWidth, height: 25))
        self.streamHeightLabel.text = "Video Height:"
        self.view.addSubview(self.streamHeightLabel)
        
        // Create Height Textfield
        self.streamHeightTextField = UITextField(frame: CGRect(x: boarder + screenWidth/2, y: 160, width: streamSizeWidth, height: 25))
        self.streamHeightTextField.text = String(self.streamHeight)
        self.streamHeightTextField.delegate = self
        
        let borderVideoHeight = CALayer()
        let widthVideoHeight = CGFloat(2.0)
        borderVideoHeight.borderColor = UIColor.darkGray.cgColor
        borderVideoHeight.frame = CGRect(x: 0, y: streamHeightTextField.frame.size.height - widthVideoHeight, width:  streamHeightTextField.frame.size.width, height: streamHeightTextField.frame.size.height)
        
        borderVideoHeight.borderWidth = widthVideoHeight
        self.streamHeightTextField.layer.addSublayer(borderVideoHeight)
        self.streamHeightTextField.layer.masksToBounds = true
        self.view.addSubview(self.streamHeightTextField)
        
        // Create Filter Lable
        self.filteredLabel = UILabel(frame: CGRect(x: boarder, y: 195, width: screenWidth-2*boarder, height: 25))
        self.filteredLabel.text = "Filter:"
        self.view.addSubview(filteredLabel)
        
        // Data Picker
        self.filter = UIPickerView(frame: CGRect(x: boarder, y: 215, width: screenWidth-2*boarder, height: 80))
        self.filter.delegate = self
        self.filter.dataSource = self
        self.filter.selectRow(filterDepth, inComponent:0, animated: true)
        self.view.addSubview(filter)
        
        // Create streamingFrequency Lable
        self.streamingFrequencyLabel = UILabel(frame: CGRect(x: boarder, y: 300, width: screenWidth-2*boarder, height: 25))
        self.streamingFrequencyLabel.text = "Chunk length (in sec):"
        self.view.addSubview(streamingFrequencyLabel)
        
        // streamingFrequencyTextField
        self.streamingFrequencyTextField = UITextField(frame: CGRect(x: boarder, y: 330, width: screenWidth-2*boarder, height: 25))
        self.streamingFrequencyTextField.text = String(self.StreamingFrequency)
        self.streamingFrequencyTextField.delegate = self
        self.view.addSubview(streamingFrequencyTextField)
        
        // streamingFrequencyTextField underline
        let borderstreamingFrequencyWidth = CALayer()
        let widthstreamingFrequencyWidth = CGFloat(2.0)
        borderstreamingFrequencyWidth.borderColor = UIColor.darkGray.cgColor
        borderstreamingFrequencyWidth.frame = CGRect(x: 0, y: self.streamWidthTextField.frame.size.height - widthVideoWidth, width:  self.streamWidthTextField.frame.size.width, height: streamWidthTextField.frame.size.height)
        
        borderstreamingFrequencyWidth.borderWidth = widthstreamingFrequencyWidth
        self.streamingFrequencyTextField.layer.addSublayer(borderstreamingFrequencyWidth)
        self.streamingFrequencyTextField.layer.masksToBounds = true
        self.view.addSubview(streamingFrequencyTextField)
        
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        
        // Create Buttons
        let buttonWidth = 80
        let buttonHeight = 40
        let buttonPosX = Int(screenWidth/2)
        let buttonPosY = screenHeight-buttonHeight-5*boarder
        let fontSize = CGFloat(30)

        // Create Save Button
        self.saveButton = UIButton(frame: CGRect(x: buttonPosX - boarder - buttonWidth, y: buttonPosY, width: buttonWidth, height: buttonHeight))
        self.saveButton.backgroundColor = .black
        self.saveButton.setTitle("Save", for: .normal)
        self.saveButton.addTarget(self, action:#selector(saveButtonAction(sender:)), for: .touchUpInside)
        self.saveButton.titleLabel?.font =  UIFont(name: "Arial", size: fontSize)
        self.view.addSubview(self.saveButton)
        
        // Create Return Button
        self.returnButton = UIButton(frame: CGRect(x: buttonPosX + boarder, y: buttonPosY, width: buttonWidth, height: buttonHeight))
        self.returnButton.backgroundColor = .black
        self.returnButton.setTitle("Back", for: .normal)
        self.returnButton.addTarget(self, action:#selector(backButtonAction(sender:)), for: .touchUpInside)
        self.returnButton.titleLabel?.font =  UIFont(name: "Arial", size: fontSize)
        self.view.addSubview(self.returnButton)
        
        // Change Default Button
        self.changetoDefaultButton = UIButton(frame: CGRect(x: buttonPosX - Int(200/2), y: buttonPosY + buttonHeight + boarder, width: 200, height: buttonHeight))
        self.changetoDefaultButton.backgroundColor = .black
        self.changetoDefaultButton.setTitle("Reset Default", for: .normal)
        self.changetoDefaultButton.addTarget(self, action:#selector(resetSettingsAction(sender:)), for: .touchUpInside)
        self.changetoDefaultButton.titleLabel?.font =  UIFont(name: "Arial", size: CGFloat(15))
        self.view.addSubview(changetoDefaultButton) // */
        
        // Error Label
        self.errorLabel = UILabel(frame: CGRect(x: boarder, y: screenHeight-3*boarder, width: screenWidth-2*boarder, height: 60))
        self.errorLabel.textColor = .red
        self.errorLabel.isHidden = true
        self.errorLabel.font = UIFont(name: "Arial", size: 15)
        errorLabel.numberOfLines = 0
        self.view.addSubview(self.errorLabel)
        
    }

    /**
     Sent to the view controller when the app receives a memory warning.
     Your app never calls this method directly. Instead, this method is called when the system determines that the amount of available memory is low.
     You can override this method to release any additional memory used by your view controller. If you do, your implementation of this method must call the super implementation at some point.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /**
     Disables Autorotate for this Storyboard
     */
    open override var shouldAutorotate: Bool {
        get {
            return false
        }
    }
    
    // MARK: - Triggered button actions
    /**
     Returns to main storyboard without saving the changes
     - Parameter sender: interaction with button
     */
    @IBAction func backButtonAction(sender: UIButton!) {
        print("Back Button Tapped")
        self.performSegue(withIdentifier: "backToStreaming", sender: nil)
    }
    
    // MARK: - Triggered button actions
    /**
     Returns to main storyboard without saving the changes
     - Parameter sender: interaction with button
     */
    @IBAction func resetSettingsAction(sender: UIButton!) {
        print("Reset Button Tapped")
        // TODO add here
        var myDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "streamingConfiguration", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        
        //TODO
        if let dict = myDict {
            self.EndpointUrlString = dict.value(forKey: "endpointUrlString") as! String
            self.endpointUrlStringTextField.text = self.EndpointUrlString
            let filtered = dict.value(forKey: "filterDepth") as! Bool
            self.FilterDepth = filtered ? 0 : 1
            self.filter.selectRow(self.FilterDepth, inComponent:0, animated: true)
            self.StreamWidth = dict.value(forKey: "streamWidth") as! Int
            self.streamWidthTextField.text = String(self.StreamWidth)
            self.StreamHeight = dict.value(forKey: "streamHeight") as! Int
            self.streamHeightTextField.text = String(self.streamHeight)
            self.StreamingFrequency = dict.value(forKey: "streamingFrequency") as! Double
            self.streamingFrequencyTextField.text = String(self.StreamingFrequency)
        }
    }
    
    /**
     Saves the current settings and returns to the main storyboard
     - Author: Simon Reisinger
     */
    @IBAction func saveButtonAction(sender: UIButton!) {
        print("Save Button Tapped")
        checkIfValuesAreValid()
        if (allValuesAreValid) {
            self.performSegue(withIdentifier: "backToStreaming", sender: nil)
        } else {
            self.errorLabel.isHidden = false
        }
    }

    /**
     Checks if the currently set values in the textfields/Data Picker are valied or not
     - Author: Simon Reisinger
     */
    func checkIfValuesAreValid(){
        self.allValuesAreValid = true
        // Check if all Values are Correct before sending them
        if (endpointUrlStringTextField.text == nil || (self.endpointUrlStringTextField.text?.count)! <= 1) {
            self.allValuesAreValid = false
            self.errorLabel.text = "url is not valid"
            self.endpointUrlStringTextField.backgroundColor = .red
            print(self.endpointUrlStringTextField.text?.count)
        } else {
            self.endpointUrlStringTextField.backgroundColor = UIColor(white: 1, alpha: 0)
        }
        let choice = filter.selectedRow(inComponent: 0)
        if (choice != 0 && choice != 1) {
            self.allValuesAreValid = false
            self.errorLabel.text = "Filter value is not valid"
            self.filter.backgroundColor = .red
        } else {
            self.filter.backgroundColor = UIColor(white: 1, alpha: 0)
        }
        if (self.streamWidthTextField.text != nil && (self.streamWidthTextField.text?.count)! > 1) {
            let newStreamWidth = Int(self.streamWidthTextField.text!)
            if (newStreamWidth == nil || newStreamWidth! <= 0 || newStreamWidth! > 20000) { //TODO Values Correct anpassen
                self.allValuesAreValid = false
                self.errorLabel.text = "The Video Stream Width must be bigger than 0 and smaler than 20000" //TODO Values Correct anpassen
                self.streamWidthTextField.backgroundColor = .red
            } else {
                self.streamWidthTextField.backgroundColor = UIColor(white: 1, alpha: 0)
            }
        } else {
            self.allValuesAreValid = false
            self.errorLabel.text = "Video Stream Width is not valid"
        }
        if (self.streamHeightTextField.text != nil && (self.streamHeightTextField.text?.count)! > 1) {
            let newStreamHeight = Int(streamHeightTextField.text!)
            if (newStreamHeight == nil || newStreamHeight! <= 0 || newStreamHeight! > 20000) { // TODO Values Correct anpassen
                self.allValuesAreValid = false
                self.errorLabel.text = "The Video Stream Height must be bigger than 0 and smaler than 20000" // TODO Values Correct anpassen
                self.streamHeightTextField.backgroundColor = .red
            } else {
                self.streamHeightTextField.backgroundColor = UIColor(white: 1, alpha: 0)
            }
        } else {
            allValuesAreValid = false
            self.errorLabel.text = "Video Stream Height is not valid"
            streamHeightTextField.backgroundColor = .red
        }
        if (streamingFrequencyTextField.text != nil && (streamingFrequencyTextField.text?.count)! >= 1) {
            let streamingFrequencyTextField = Double(self.streamingFrequencyTextField.text!)
            if (streamingFrequencyTextField == nil || streamingFrequencyTextField! <= 0) {
                self.allValuesAreValid = false
                self.errorLabel.text = "Streaming Frequency must be a Double and bigger 0 in Seconds"
                self.streamingFrequencyTextField.backgroundColor = .red
            } else {
                self.streamingFrequencyTextField.backgroundColor = UIColor(white: 1, alpha: 0)
            }
        } else {
            allValuesAreValid = false
            self.errorLabel.text = "Video Streaming Frequency is not valid"
            self.streamingFrequencyTextField.backgroundColor = .red
        }
    } 

    /**
     Notifies the view controller that a segue is about to be performed.
     The default implementation of this method does nothing. Subclasses override this method and use it to configure the new view controller prior to it being displayed. The segue object contains information about the transition, including references to both view controllers that are involved.
     Because segues can be triggered from multiple sources, you can use the information in the segue and sender parameters to disambiguate between different logical paths in your app. For example, if the segue originated from a table view, the sender parameter would identify the table view cell that the user tapped. You could then use that information to set the data on the destination view controller.
     - Parameter segue: The segue object containing information about the view controllers involved in the segue.
     - Parameter sender: The object that initiated the segue. You might use this parameter to perform different actions based on which control (or other object) initiated the segue.
     */
    internal override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(allValuesAreValid && segue.identifier == "backToStreaming") {
                        
            let yourNextViewController = (segue.destination as! ViewController)
            if (endpointUrlStringTextField.text != nil && (endpointUrlStringTextField.text?.count)! > 1) {
                yourNextViewController.EndpointUrlString = endpointUrlStringTextField.text!
                UserDefaults.standard.set(endpointUrlStringTextField.text!, forKey: "endpointUrlString")
            }
            let choice = filter.selectedRow(inComponent: 0)
            if (choice == 0 || choice == 1) {
                yourNextViewController.FilterDepth = choice
                UserDefaults.standard.set(choice == 0, forKey: "filterDepth")
            }
            if (endpointUrlStringTextField.text != nil && (endpointUrlStringTextField.text?.count)! > 1) {
                let newStreamWidth = Int(streamWidthTextField.text!)
                if (newStreamWidth != nil && newStreamWidth! > 0 && newStreamWidth! <= 20000) { //TODO Values Correct anpassen
                    yourNextViewController.StreamWidth = newStreamWidth!
                    UserDefaults.standard.set(newStreamWidth!, forKey: "streamWidth")
                }
            }
            if (endpointUrlStringTextField.text != nil && (endpointUrlStringTextField.text?.count)! > 1) {
                let newStreamHeight = Int(streamHeightTextField.text!)
                if (newStreamHeight != nil && newStreamHeight! > 0 && newStreamHeight! <= 20000) { //TODO Values Correct anpassen
                    yourNextViewController.StreamHeight = newStreamHeight!
                    UserDefaults.standard.set(newStreamHeight!, forKey: "streamHeight")
                }
            }
            if (streamingFrequencyTextField.text != nil) {
                let streamingFrequencyTextField = Double(self.streamingFrequencyTextField.text!)
                if (streamingFrequencyTextField != nil && streamingFrequencyTextField! > 0) {
                    yourNextViewController.StreamingFrequency = streamingFrequencyTextField!
                    UserDefaults.standard.set(streamingFrequencyTextField!, forKey: "streamingFrequency")
                }
            }

            
            // add here further in formation
        } else if (!allValuesAreValid && segue.identifier == "backToStreaming"){
            let yourNextViewController = (segue.destination as! ViewController)
            yourNextViewController.EndpointUrlString = self.endpointUrlString
            yourNextViewController.FilterDepth = self.filterDepth
            yourNextViewController.StreamWidth = self.streamWidth
            yourNextViewController.StreamHeight = self.streamHeight
            yourNextViewController.StreamingFrequency = self.streamingFrequency
        }
    }
 
    // MARK: - DataPicker
    /**
     Asks the delegate if the text field should process the pressing of the return button.
     The text field calls this method whenever the user taps the return button. You can use this method to implement any custom behavior when the button is tapped. For example, if you want to dismiss the keyboard when the user taps the return button, your implementation can call the resignFirstResponder() method.
     - Parameter textField: The text field whose return button was pressed.
     - Returns: true if the text field should implement its default behavior for the return button; otherwise, false.
     */
    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    /**
     Called by the picker view when it needs the number of components.
     - Parameter pickerView: The picker view requesting the data.
     - Returns: The number of components (or “columns”) that the picker view should display.
     */
    internal func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    /**
     Called by the picker view when it needs the number of rows for a specified component.
     - Parameter pickerView: The picker view requesting the data.
     - Parameter component: A zero-indexed number identifying a component of pickerView. Components are numbered left-to-right.
     - Returns: The number of rows for the component.
     */
    internal func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.filterPossibilities.count
    }
    
    /**
     Called by the picker view when it needs the title to use for a given row in a given component.
     If you implement both this method and the pickerView(_:attributedTitleForRow:forComponent:) method, the picker view prefers the pickerView(_:attributedTitleForRow:forComponent:) method. However, if that method returns nil, the picker view falls back to using the string returned by this method.
     - Parameter pickerView: An object representing the picker view requesting the data.
     - Parameter row: A zero-indexed number identifying a row of component. Rows are numbered top-to-bottom.
     - Parameter component: A zero-indexed number identifying a component of pickerView. Components are numbered left-to-right.
     - Returns: The string to use as the title of the indicated component row.
     */
    internal func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int ) -> String? {
        return self.filterPossibilities[row]
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
