//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by Eros Campos on 7/2/20.
//

import UIKit
import AVFoundation
import Photos
import Speech

import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout, AVAudioRecorderDelegate, UISearchBarDelegate {

    //For the search bar
    var searchQuery: CSSearchQuery?
    
    //Memories
    var memories = [URL]()
    var filteredMemories = [URL]()
    var activeMemory: URL!
    
    //Audio record
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var recordingURL: URL!
    
    
    //MARK: - SYSTEM SETUP AND DELEGATES
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        recordingURL = getDocumentDirectory().appendingPathComponent("recording.m4a")
        
        //print("RECORDING URL: \(recordingURL!)")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteTapped))
        loadMemories()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return filteredMemories.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell
        
        let memory = filteredMemories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path

        let image = UIImage(contentsOfFile: imageName)
        cell.imageView.image = image

        //ADD GESTURE RECOGNIZERS FOR RECORDINGS
        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = filteredMemories[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path) {
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
            
        } catch {
            print("error loading audio")
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
    
    //In case the recording is forcefully ended (ex. a call)
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    //MARK: - GESTURE RECOGNIZERS
    //GETS THE URL OF THE CELL USING THE GESTURE
    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell
        
            if let index = collectionView?.indexPath(for: cell) {
                activeMemory = filteredMemories[index.row]
                //print("ACTIVE MEMORY: \(activeMemory!)")
                recordMemory()
            }
            
        } else if (sender.state == .ended) {
            finishRecording(success: true)
        }
    }
    
    //MARK: - RECORD AND AUDIO FUNCTIONS
    func recordMemory() {
        //0. Stop audio if its playing
        audioPlayer?.stop()
        
        //1. Change colors to show its recording audio
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        let recordingSession = AVAudioSession.sharedInstance()
        do {
           //2. Configure the session recording and playback trought the speaker
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)
            
            //3. Set up a high quality recording session
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            //4. Create the audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            
        } catch let error {
            //..if theres an error during recording
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        //1 Set background back to normal.
        collectionView?.backgroundColor = UIColor.darkGray
        
        //2. Stop the recording
        audioRecorder?.stop()
        
        if success {
            do {
                //3. Create an URL of the audio with the memory name
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                //print("MEMORY AUDIO URL: \(memoryAudioURL)")
                
                //4. If there already exists a recording, delete it to replace it
                if fm.fileExists(atPath: memoryAudioURL.path) {
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                //5. Move the recorded file into the memory's audio URL ???????????
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                //6. Start transcibing the audio
                transcribeAudio(memory: activeMemory)
                
            } catch let error {
                print("Failed finishing recording: \(error)")
            }
        }
    }
    
    func transcribeAudio(memory: URL) {
        //Get paths to where the audio is, and where the transcription should be
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        //Create a new recognizer and point it at our audio
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
     
        //Start recognition
        recognizer?.recognitionTask(with: request, resultHandler: {[unowned self] (result, error) in
            //Abort if we didnt get any transcription back
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }
            
            //If we got the final transcription back, we write it to disc
            if result.isFinal {
                //Pull out the best transcription...
                //let text = result.bestTranscription.formattedString
                let transcriptionsArray = result.transcriptions
                                
                //...and write it to disk at the correct filename for this memory
                do {
                    //Save the best translation
                    //try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    
                    try transcriptionsArray[0].formattedString.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    print("BEST TRANSCRIBED TEXT: \(transcriptionsArray[0].formattedString)")

                    //Put every translation searchable in Spotlight
                    self.indexMemory(memory: memory, transcriptionArray:transcriptionsArray)
                    
                    
                } catch  {
                    print("Failed to save transcription.")
                }
            }
        })
    }
    
    //MARK: - FUNCTION TO USE iOS SPOTLIGHT
    func indexMemory(memory: URL, transcriptionArray: [SFTranscription]) {
        var items: [CSSearchableItem] = []
        
        for (index, transcription) in transcriptionArray.enumerated() {
            //Create a basic attribute set
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
            attributeSet.title = "Happy Days Memory"
            attributeSet.contentDescription = transcription.formattedString
            attributeSet.thumbnailURL = thumbnailURL(for: memory)
            
            //Wrap it in a Searchable Item, using the memory's full path as its unique identifier
            let item = CSSearchableItem(uniqueIdentifier: "\(memory.lastPathComponent)&transc\(index)", domainIdentifier: "com.happydays", attributeSet: attributeSet)
            
            //Make it never expire
            item.expirationDate = Date.distantFuture
            
            //Add it to the array
            items.append(item)
        }
        
        //Ask Spotlight to index the item
        CSSearchableIndex.default().indexSearchableItems(items, completionHandler: { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                for item in items {
                    print("Correctly Indexed: \(item.uniqueIdentifier)")
                }
            }
        })
    }
    
    //MARK: - SEARCHBAR DELEGATES AND FUNCTIONS
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterMemories(text: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterMemories(text: String) {
        //If theres no text in the searchbar, default the list
        guard text.count > 0 else {
            filteredMemories = memories
            
            UIView.performWithoutAnimation {
                collectionView.reloadSections(IndexSet(integer: 1))
            }
            return
        }
        
        var allItems = [CSSearchableItem]()
        searchQuery?.cancel()
        
        //find things that have a contentDescription value equal to any text, followed by our search text, then any text, using case-insensitive matching.
        let queryString = "contentDescription == \"*\(text)*\"c"
        
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        searchQuery?.foundItemsHandler = { items in
            allItems.append(contentsOf: items)
        }
        
        searchQuery?.completionHandler = { error in
            DispatchQueue.main.async { [unowned self] in
                self.activateFilter(matches: allItems)
            }
        }
        
        searchQuery?.start()
    }
    
    //Create the filteredMemories array based on the searched items
    func activateFilter(matches: [CSSearchableItem]) {
        //Get the memories with the URL + item uniqueIdentifier without their id
        let tempMemories: [URL] = matches.map({ item in
            //print(item.uniqueIdentifier)
            print(Helper.getBaseString(uniqueIdentifier: item.uniqueIdentifier)!)
            return URL(fileURLWithPath: "\(getDocumentDirectory().absoluteString)/\(Helper.getBaseString(uniqueIdentifier: item.uniqueIdentifier)!)")
            })
        
        //Remove any duplicated URL in the array
        filteredMemories = tempMemories.removingDuplicates()

        //Reload the items section
        UIView.performWithoutAnimation {
            collectionView?.reloadSections(IndexSet(integer: 1))
        }
    }

    
    //MARK: - CUSTOM FUNCTIONS
    //1. show Image picker
    @objc func addTapped(){
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true)
    }
    
    @objc func deleteTapped(){
        
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            if fileURLs.count > 0{
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
            }
            
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.happydays"], completionHandler: { error in
                if let error = error {
                    print("Error deleting indexes: \(error)")
                } else {
                    print("Successfully deleted indexes")
                }
            })
            
            loadMemories()
            
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
    
    
    
    
    //2. Selecting the image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true)
        if let possibleImage = info[.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
    
    //3 Saving into memory
    func saveNewMemory(image: UIImage){
        //Creating a unique name for the memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        //Use the unique name to create filenames for the full-size image and the thumbnail
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"
        
        do {
            //create a URL to where to write the JPEG to
            let imagePath = getDocumentDirectory().appendingPathComponent(imageName)
            
            //convert the UIImage into a JPEG data object
            if let jpegData = image.jpegData(compressionQuality: 0.8){
                //Write the data into the created URL
                try jpegData.write(to: imagePath, options: [.atomic])
            }
            
            //Create thumbnail here
            if let thumbnail = resize(image: image, to: 200){
                let imagePath = getDocumentDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = thumbnail.jpegData(compressionQuality: 0.8){
                    try jpegData.write(to: imagePath, options: [.atomic])
                }
            }
            
            
        } catch {
            print("Failed to save to disk..")
        }
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        //calculate how much we need to bring the width down to match the target size
        let scale = width / image.size.width
        
        //bring the height down by the same amount so that the aspect ratio is preserved
        let height = image.size.height * scale
        
        //create a new image context we can draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        //draw the original image into the context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        //Pull out the resized version
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        //End the context so UIKit can clean up
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func checkPermissions() {
         // check status for all three permissions
         let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
         let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
         let transcibeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
         // make a single boolean out of all three
         let authorized = photosAuthorized && recordingAuthorized && transcibeAuthorized
         // if we're missing one, show the first run screen
        
        //print("PERMISSIONS AUTHORIZED?: \(authorized)")
         if authorized == false {
             if let vc =
            storyboard?.instantiateViewController(withIdentifier:
            "FirstRun") {
             navigationController?.present(vc, animated: true)
             }
         }
    }
    
    func getDocumentDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
//        print("the path directory is \(paths[0])")
        return documentsDirectory
    }

    func loadMemories(){
        memories.removeAll()
        
        //Attempt to load all the memories in our documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
//        print("the files in the directory: \(files)")
        
        //Loop over every file found
        for file in files {
            let filename = file.lastPathComponent
            
            //Check if the file ends with .thumb so we dont count each memory more than once
            if filename.hasSuffix(".thumb") {
                //Get the root name of the memory (i.e., without its path extension)
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                //Create a full path from the memory
                let memoryPath = getDocumentDirectory().appendingPathComponent(noExtension)
                
                //Add it to the array
                memories.append(memoryPath)
            }
        }
        //print("MEMORIES: \(memories)")
        
        //By default, filteredMemories should contain all the memories
        filteredMemories = memories
        
        //reload our list of memories
        collectionView?.reloadSections(IndexSet(integer: 1))
    }
    
    //HELPERS
    func imageURL(for memory:URL) -> URL{
        return memory.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(for memory:URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory:URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory:URL) -> URL {
        return memory.appendingPathExtension("txt")
    }
    
    
}
