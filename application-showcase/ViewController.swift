//
//  ViewController.swift
//  application-showcase
//
//  Created by Casey Lyman on 5/21/16.
//  Copyright © 2016 bearcode. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKLoginKit
import Firebase

class ViewController: UIViewController {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if NSUserDefaults.standardUserDefaults().valueForKey(KEY_UID) != nil {
            self.performSegueWithIdentifier(SEGUE_LOGGED_IN, sender: nil)
        }
    }
    
    @IBAction func fbBtnPressed (sender: UIButton!) {
        
        let facebookLogin = FBSDKLoginManager()
        
        facebookLogin.logInWithReadPermissions(["email"], fromViewController: self) { (facebookResult: FBSDKLoginManagerLoginResult!, facebookError: NSError!) in
            
            if facebookError != nil {
                print("Facebook login failed. Error \(facebookError)")
            } else if facebookResult.isCancelled {
                print("Facebook login was cancelled")
            } else {
                let accessToken = FBSDKAccessToken.currentAccessToken().tokenString
                
                print("Successfully logged in \(accessToken)")

                let credential = FIRFacebookAuthProvider.credentialWithAccessToken(accessToken)
                
                FIRAuth.auth()?.signInWithCredential(credential, completion: { (user, error) in
                    
                    if error != nil {
                        print("Login error. \(error)")
                    } else {
                        print("Successfully logged in \(user)")
                        
                        if let uid = user?.uid {
                            
                            var provider = credential.provider
                            if provider == "" {
                                provider = "unknown"
                            }
                            
                            let userData = ["provider": provider]
                            DataService.ds.createFirebaseUser(uid, user: userData)
                        
                            NSUserDefaults.standardUserDefaults().setValue(user!.uid, forKey: KEY_UID)
                            self.performSegueWithIdentifier(SEGUE_LOGGED_IN, sender: nil)
                        }
                        
                    }
                })
            }
        }
    }
    
    @IBAction func attemptLogin(sender: UIButton!) {
        
        if let email = emailField.text where email != "", let pwd = passwordField.text where pwd != "" {
            
//            DataService.ds.REF_BASE.authUser(email, password: pwd, withCompletionBlock: { error, authData in
            FIRAuth.auth()?.signInWithEmail(email, password: pwd, completion: { (user, error) in
                
                if error != nil {
                    print("\(error)")

                    if let errorCode = error?.code {
                        switch (errorCode) {
                        case FIRAuthErrorCode.ErrorCodeUserNotFound.rawValue:

                            FIRAuth.auth()?.createUserWithEmail(email, password: pwd, completion: { (user, error) in
                                
                                if error != nil {
                                    self.showErrorAlert("Could not create account", message: "Problem creating account. Try something else")
                                } else {
                                    print("\(user?.uid)")
                                    
                                    if let uid = user?.uid {
                                        
//                                        var provider = authData.provider
//                                        if provider == nil {
//                                            provider = "unknown"
//                                        }
                                        
                                        let userData = ["provider": "email"]
                                        DataService.ds.createFirebaseUser(uid, user: userData)
                                        
                                        NSUserDefaults.standardUserDefaults().setValue(uid, forKey: KEY_UID)
                                        self.performSegueWithIdentifier(SEGUE_LOGGED_IN, sender: nil)
                                    }
                                }
                                
                            })
                        case FIRAuthErrorCode.ErrorCodeInvalidEmail.rawValue:
                            print("Invalid Email")
                            self.showErrorAlert("Invalid Email", message: "The email address entered is not valid")
                        case FIRAuthErrorCode.ErrorCodeWrongPassword.rawValue:
                            print("Invalid Password")
                             self.showErrorAlert("Invalid Password", message: "The password entered is not valid")
                        default:
                            print("Need to do something")
                            self.showErrorAlert("Account login in Error", message: "Check username and password")
                        }
                    } else {
                        self.performSegueWithIdentifier(SEGUE_LOGGED_IN, sender: nil)
                    }
                }
            })
            
        } else {
            showErrorAlert("Email and Password Required", message: "You must enter an email and password")
        }
        
    }
    
    func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.Default, handler: nil)
        alert.addAction(action)
        presentViewController(alert, animated: true, completion: nil)
    }


}

