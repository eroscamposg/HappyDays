//
//  ViewController.swift
//  HappyDays
//
//  Created by Eros Campos on 7/2/20.
//

import UIKit
import AVFoundation
import Photos
import Speech


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBOutlet weak var helpLabel: UILabel!
    
    @IBAction func requestPermissions(_ sender: UIButton) {
        requestPhotoPermissions()
    }
    
    func requestPhotoPermissions(){
        PHPhotoLibrary.requestAuthorization{ [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordPermissions()
                } else {
                    self.helpLabel.text = "Photos permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    func requestRecordPermissions(){
        AVAudioSession.sharedInstance().requestRecordPermission(){
            [unowned self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self.requestTranscribePermissions()
                } else {
                    self.helpLabel.text = "Recording permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    func requestTranscribePermissions(){
        SFSpeechRecognizer.requestAuthorization{
            [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.authorizationComplete()
                } else {
                    self.helpLabel.text = "Transcription permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    func authorizationComplete(){
        dismiss(animated: true)
    }
}

