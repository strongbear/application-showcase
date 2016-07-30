//
//  PostCell.swift
//  application-showcase
//
//  Created by Casey Lyman on 5/22/16.
//  Copyright © 2016 bearcode. All rights reserved.
//

import UIKit
import Alamofire
import AWSS3
import Firebase

class PostCell: UITableViewCell {
    
    @IBOutlet weak var profileImg: UIImageView!
    @IBOutlet weak var showcaseImg: UIImageView!
    @IBOutlet weak var descriptionText: UITextView!
    @IBOutlet weak var likesLbl: UILabel!
    @IBOutlet weak var likeImage: UIImageView!
    
    var post: Post!
    var request: Request?
    var likeRef: FIRDatabaseReference!

    override func awakeFromNib() {
        super.awakeFromNib()
        let tap = UITapGestureRecognizer(target: self, action: #selector(PostCell.likeTapped))
        tap.numberOfTapsRequired = 1
        likeImage.addGestureRecognizer(tap)
        likeImage.userInteractionEnabled = true
    }
    
    override func drawRect(rect: CGRect) {
        profileImg.layer.cornerRadius = 8.0
        profileImg.clipsToBounds = true
        
        showcaseImg.clipsToBounds = true
    }
    
    func configureCell(post: Post, img: UIImage?) {
        self.post = post
        likeRef = DataService.ds.REF_USER_CURRENT.childByAppendingPath("likes").childByAppendingPath(post.postKey)

        self.descriptionText.text = post.postDescription
        self.likesLbl.text = "\(post.likes)"
        
        if post.imageUrl != nil {
            
            if img != nil {
                self.showcaseImg.image = img
            } else {
                if post.imageUrl!.rangeOfString("http") != nil {
                    request = Alamofire.request(.GET, post.imageUrl!).validate(contentType: ["image/*"]).response(completionHandler: { request, response, data, err in
                        if err == nil {
                            let img = UIImage(data: data!)!
                            self.showcaseImg.image = img
                            FeedVC.imageCache.setObject(img, forKey: self.post.imageUrl!)
                        }
                    })
                } else {
                    print("Amazon S3 image request goes here")
                    let transferManager = AWSS3TransferManager.defaultS3TransferManager()
                    let downloadFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(post.imageUrl!)
                    let downloadFileUrl = NSURL(fileURLWithPath: downloadFilePath)
                    
                    let downloadRequest = AWSS3TransferManagerDownloadRequest()
                    downloadRequest.bucket = "application-showcase"
                    downloadRequest.key = post.imageUrl!
                    downloadRequest.downloadingFileURL = downloadFileUrl
                    
                    transferManager.download(downloadRequest).continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: { (task: AWSTask) -> AnyObject? in
                        
                        if let error = task.error {
                            if error.domain == AWSS3TransferManagerErrorDomain as String && AWSS3TransferManagerErrorType(rawValue: error.code) == AWSS3TransferManagerErrorType.Paused {
                                print("Download Paused")
                            } else {
                                print("Download Failed [\(error)]")
                            }
                            
                        } else if let exception = task.exception {
                            print("Download Exception: [\(exception)]")
                        } else if let result = task.result {
                            let downloadOutput = result as! AWSS3TransferManagerDownloadOutput
                            print("\(downloadOutput)")
                            let img = UIImage(contentsOfFile: downloadFilePath)
                            self.showcaseImg.image = img
                            FeedVC.imageCache.setObject(img!, forKey: self.post.imageUrl!)
                            
                        } else {
                            print("Something else [\(task.debugDescription)]")
                        }
                        
                        return nil
                        
                    })
                }
            }
        } else {
            self.showcaseImg.hidden = true
        }
        
        likeRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
            
            if let doesNotExist = snapshot.value as? NSNull {
                self.likeImage.image = UIImage(named: "heart-empty")
            } else {
                self.likeImage.image = UIImage(named: "heart-full")
            }
            
        })
        
    }
    
    func likeTapped(sender: UITapGestureRecognizer) {
        likeRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
            
            if let doesNotExist = snapshot.value as? NSNull {
                self.likeImage.image = UIImage(named: "heart-full")
                self.post.adjustLikes(true)
                self.likeRef.setValue(true)
            } else {
                self.likeImage.image = UIImage(named: "heart-empty")
                self.post.adjustLikes(false)
                self.likeRef.removeValue()
            }
            
        })
    }


}
