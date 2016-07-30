//
//  FeedVC.swift
//  application-showcase
//
//  Created by Casey Lyman on 5/22/16.
//  Copyright © 2016 bearcode. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import AWSS3

class FeedVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var postField: MaterialTextField!
    @IBOutlet weak var imageSelectorImage: UIImageView!
    
    var defaultPostImg: UIImage!
    
    
    var posts = [Post]()
    var imagePicker: UIImagePickerController!
    static var imageCache = NSCache()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 358
        
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        DataService.ds.REF_POSTS.observeEventType(.Value, withBlock: { snapshot in
            print(snapshot.value)
            
            self.posts = []
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                for snap in snapshots {
                    
                    if let postDict = snap.value as? Dictionary<String, AnyObject> {
                        
                        let key = snap.key
                        let post = Post(postKey: key, dictionary: postDict)
                        self.posts.append(post)
                    }
                }
            }
            
            self.tableView.reloadData()
        })

    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let tmpImg = UIImage(named: "camera.png")!
        defaultPostImg = tmpImg
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return  1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let post = posts[indexPath.row]
        
        if let cell = tableView.dequeueReusableCellWithIdentifier("PostCell") as? PostCell {
            
            cell.request?.cancel()
            var img: UIImage?
            
            if let url = post.imageUrl {
                img = FeedVC.imageCache.objectForKey(url) as? UIImage
            }
            cell.configureCell(post, img: img)
            return cell
        } else {
            return PostCell()
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        let post = posts[indexPath.row]
        
        if post.imageUrl == nil {
            return 150
        } else {
            return tableView.estimatedRowHeight
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        imagePicker.dismissViewControllerAnimated(true, completion: nil)
        imageSelectorImage.image = image
    }

    @IBAction func selectImage(sender: UITapGestureRecognizer) {
        presentViewController(imagePicker, animated: true, completion: nil)
    }

    @IBAction func makePost(sender: AnyObject) {
        
        if let txt = postField.text where txt != "" {
            
            if let img = imageSelectorImage.image {
                
                if image(defaultPostImg, isEqualTo: img) {
                    print("No Image Selected")
                    self.postToFirebase(nil)
                } else {
                    print("Image selected go ahead and post image to AWSS3")
                    // this is where i figure out how to upload image to AWSS3
                    let transferManager = AWSS3TransferManager.defaultS3TransferManager()
                    let uploadRequest = AWSS3TransferManagerUploadRequest()
                    
                    let fileName = NSProcessInfo.processInfo().globallyUniqueString.stringByAppendingString(".jpg")
                    let fileUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(fileName)
                    let filePath = fileUrl.path!
                    let imageData = UIImageJPEGRepresentation(img, 0.2)
                    imageData!.writeToFile(filePath, atomically: true)
                    
                    uploadRequest.body = fileUrl
                    uploadRequest.key = fileName
                    uploadRequest.bucket = "application-showcase"
                    
                    transferManager.upload(uploadRequest).continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: { (task: AWSTask) -> AnyObject? in
                        
                        if let error = task.error {
                            if error.domain == AWSS3TransferManagerErrorDomain as String && AWSS3TransferManagerErrorType(rawValue: error.code) == AWSS3TransferManagerErrorType.Paused {
                                print("Upload Paused")
                            } else {
                                print("Upload Failed [\(error)]")
                            }
                        } else if let exception = task.exception {
                            print("Upload Exception \(exception)")
                        } else {
                            print("Maybe it worked")
                        }
                        
                        if let result = task.result {
                            let uploadOutput = result as! AWSS3TransferManagerUploadOutput
                            print("\(uploadOutput)")
                            self.postToFirebase(fileName)
                        }
                        
                        return nil
                    })
                }
            }
        }
        
    }
    
    func image(image1: UIImage, isEqualTo image2: UIImage) -> Bool {
        let data1: NSData = UIImagePNGRepresentation(image1)!
        let data2: NSData = UIImagePNGRepresentation(image2)!
        return data1.isEqual(data2)
    }
    
    func postToFirebase(imgUrl: String?){
        var post: Dictionary<String, AnyObject> = [
            "description":postField.text!,
            "likes":0
        ]
        
        if imgUrl != nil {
            post["imageUrl"] = imgUrl!
        }
        
        let firebasePost = DataService.ds.REF_POSTS.childByAutoId()
        firebasePost.setValue(post)
        
        postField.text = ""
        imageSelectorImage.image = UIImage(named: "camera")
        
        tableView.reloadData()
        
    }
}
