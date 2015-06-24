//
//  AppDelegate.swift
//  test1
//
//  Created by Ivy Chung on 5/22/15.
//  Copyright (c) 2015 Patrick Chang. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import UIKit

import CoreLocation
import CoreMotion
import SystemConfiguration

public class Reachability {
    
    class func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return (isReachable && !needsConnection) ? true : false
    }
    
}

extension NSURLSessionTask{ func start(){
    self.resume() }
}


@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    
    //location & activity tracking variables
    var window: UIWindow?
    var locationManager: CLLocationManager!
    var seenError : Bool = false
    var locationFixAchieved : Bool = false
    var locationStatus : NSString = "Not Started"
    let activityManager: CMMotionActivityManager = CMMotionActivityManager()
    let dataProcessingQueue = NSOperationQueue()
    //server upload variables
    var locationLongitude = "initLong"
    var locationLatitude = "initLat"
    var activityType = "initAct"
    var activityConfidence = "initConf"
    var offlineUpload = [[String]]()
    var uploadContents = ["lat", "long", "UNKNOWN", "conf", "timestamp", "timezone", "speed", "batteryLeft", "connection"]
    var oldTime = NSDate().timeIntervalSince1970
    var uploadString = ""
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        initLocationManager();
        return true
    }
    
    // Location Manager helper stuff
    func initLocationManager() {
        
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        seenError = false
        locationFixAchieved = false
        locationManager = CLLocationManager()
        locationManager.delegate = self
        //locationManager.locationServicesEnabled
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = 0
        locationManager.requestAlwaysAuthorization()
    }
    
    // Location Manager Delegate stuff
    // If failed
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        locationManager.stopUpdatingLocation()
        if ((error) != nil) {
            if (seenError == false) {
                seenError = true
                print(error)
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        //if (locationFixAchieved == false) {
            locationFixAchieved = true
            let tracking = NSEntityDescription.insertNewObjectForEntityForName("Tracking", inManagedObjectContext: self.managedObjectContext!) as! Tracking
            var speed = 0.0
            var locationArray = locations as NSArray
            var locationObj = locationArray.lastObject as! CLLocation
            var coord = locationObj.coordinate
            var batchString = ""
            //println(coord.latitude)
            //println(coord.longitude)
            //println(locationObj.timestamp)
            self.locationLongitude = "\(coord.longitude)"
            self.locationLatitude = "\(coord.latitude)"
            tracking.longitude = self.locationLongitude
            tracking.latitude = self.locationLatitude
            uploadContents[0] = self.locationLatitude
            uploadContents[1] = self.locationLongitude
            uploadContents[6] = "\(locationObj.speed)"
            self.activityManager.startActivityUpdatesToQueue(self.dataProcessingQueue) {
            data in
            dispatch_async(dispatch_get_main_queue()) {
                if data.confidence == CMMotionActivityConfidence.Low {
                    self.activityConfidence = "low"
                } else if data.confidence == CMMotionActivityConfidence.Medium {
                    self.activityConfidence = "medium"
                } else if data.confidence == CMMotionActivityConfidence.High {
                    self.activityConfidence = "high"
                } else {
                    self.activityConfidence = "There was a problem getting confidence"
                }
                if data.running {
                    //println("the current activity is running")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.activityType = "RUNNING"
                }; if data.cycling {
                    //println("the current activity is cycling")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.activityType = "ON_BICYCLE"
                };if data.walking {
                    //println("the current activity is walking")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.activityType = "WALKING"
                }; if data.automotive && speed > 15.0{
                    //println("the current activity is automotive")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = false
                    self.activityType = "IN_VEHICLE"
                }; if data.stationary{
                    //println("the current activity is stationary")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.activityType = "STILL"
                }; if data.unknown {
                    //println("the current activity is unknown")
                    self.activityManager.stopActivityUpdates()
                    //self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.activityType = "UNKNOWN"
                }
                //var googleActivity :String = self.convertToGoogleActivityType(self.activityType)
                self.uploadContents[2] = self.activityType
                self.uploadContents[3] = self.activityConfidence
                tracking.activity = self.activityType
                tracking.confidence = self.activityConfidence
                }
        }
        tracking.timestamp = "\(Int(NSDate().timeIntervalSince1970))"
        tracking.timezone = "\(NSTimeZone.localTimeZone().abbreviation)"
        //uploadContents[4] = tracking.timestamp
        uploadContents[5] = tracking.timezone
        //
        //
        //
        let date = NSDate();
        let dateFormatter = NSDateFormatter()
        //To prevent displaying either date or time, set the desired style to NoStyle.
        dateFormatter.timeStyle = NSDateFormatterStyle.LongStyle //Set time style
        dateFormatter.dateStyle = NSDateFormatterStyle.LongStyle //Set date style
        dateFormatter.timeZone = NSTimeZone()
        let localDate = dateFormatter.stringFromDate(date)
        uploadContents[4] = localDate
        //var googleActivity :String = convertToGoogleActivityType(tracking.activity)
        //var tempElement = [tracking.longitude, tracking.latitude, tracking.activity, tracking.confidence, tracking.timestamp, tracking.timezone]
        //batchString = batchStringBuilder(uploadContents[4], latitude: uploadContents[1], longitude: uploadContents[0], activity: uploadContents[2], speed: uploadContents[6])
        uploadString = uploadString + batchString
        //println(uploadString)
        if UIDevice.currentDevice().batteryMonitoringEnabled == false{
            println("cannot monitor battery")
        }
        var batteryLeft = ""
        batteryLeft = "\(UIDevice.currentDevice().batteryLevel*100)"
        uploadContents[7] = batteryLeft
        //offlineUpload.append(uploadContents)
        //println(offlineUpload)
        if Reachability.isConnectedToNetwork() == false {
            println("cannot connect to web")
        }
        println(offlineUpload.count)
        if Reachability.isConnectedToNetwork() {
            sendToServer(uploadContents[0], latitudeString: uploadContents[1], activityString: uploadContents[2], confidenceString: uploadContents[3], timestampString: uploadContents[4], timeZoneString: uploadContents[5], batteryChargeLeft : batteryLeft, connectionString: "Connected")
                //sendToWebservice(uploadContents[2], timestampString: uploadContents[4], latitudeString: uploadContents[1], longitudeString: uploadContents[0], speedString: uploadContents[6])
        } else {
            //println("currently offline")
            uploadContents[8] = "Not connected"
            offlineUpload.append(uploadContents)
            //println(offlineUpload.count)
        }
        
        var batteryHealthy :Bool
        if UIDevice.currentDevice().batteryState == UIDeviceBatteryState.Charging || UIDevice.currentDevice().batteryState == UIDeviceBatteryState.Full {
            batteryHealthy = true
        } else {
            batteryHealthy = false
        }
        if Reachability.isConnectedToNetwork() && offlineUpload.count > 0 {
            sendToServerBatch()
        }
        /*
        if batteryHealthy && Reachability.isConnectedToNetwork() {
            //println(offlineUpload.count)
            //println("Battery is charging and we have internet connectivity!")
            //sendBatchToWebService(uploadString)
            if offlineUpload.count > 0 {
                sendToServerBatch()
            }
            //for instance in offlineUpload {
                //sendToServer(instance[0], latitudeString: instance[1], activityString: instance[2], confidenceString: instance[3], timestampString: instance[4], timeZoneString: instance[5], batteryChargeLeft: instance[7])
                //sendToWebservice(instance[2], timestampString: instance[4], latitudeString: instance[1], longitudeString: instance[0], speedString: instance[6])
            //}
           
        }
        */
        // print out number of instances stored in database
        let fetchRequest = NSFetchRequest(entityName: "Tracking")
        var requestError: NSError?
        let trackingInstances = managedObjectContext!.executeFetchRequest(fetchRequest,error: &requestError) as! [Tracking!]
        if trackingInstances.count > 0 {
            //println("\(trackingInstances.count)")
            if trackingInstances.count%5 == 0 {
                //printFromCoreData()
            }
        }

    }
    
    // authorization status
    func locationManager(manager: CLLocationManager!,
        didChangeAuthorizationStatus status: CLAuthorizationStatus) {
            var shouldIAllow = false
            switch status {
            case CLAuthorizationStatus.Restricted:
                locationStatus = "Restricted Access to location"
            case CLAuthorizationStatus.Denied:
                locationStatus = "User denied access to location"
            case CLAuthorizationStatus.NotDetermined:
                locationStatus = "Status not determined"
            default:
                locationStatus = "Allowed to location Access"
                shouldIAllow = true
            }
            NSNotificationCenter.defaultCenter().postNotificationName("LabelHasbeenUpdated", object: nil)
            if (shouldIAllow == true) {
                NSLog("Location to Allowed")
                // Start location services
                locationManager.startUpdatingLocation()
            } else {
                NSLog("Denied access: \(locationStatus)")
            }
    }
    
    func sendBatchToWebService(urlEnding: String) {
        //println("sending batch to web service...")
        var response: NSURLResponse?
        //formatting
        var deviceID = UIDevice.currentDevice().identifierForVendor.UUIDString
        var endURL = urlEnding
        let substringIndex = count(endURL) - 1
        let newEnding = endURL.substringToIndex(advance(endURL.startIndex,substringIndex))
        //upload to web service
        
        let myUrl = NSURL(string: "http://ridesharing.cmu-tbank.com/reportActivity.php?userID=1&deviceID\(deviceID)&logs=\(newEnding)")
        println(myUrl)
        let request = NSMutableURLRequest(URL:myUrl!)
        request.HTTPMethod = "POST"
        var data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: nil) as NSData?
        if let httpResponse = response as? NSHTTPURLResponse {
            //OK
            if httpResponse.statusCode == 200 {
                //println("ok")
                if let json: NSDictionary = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary {
                   // println("stage 1 passed")
                    if let success = json["success"] as? Bool {
                        //println(success)
                        if let message = json["message"] as? NSString {
                            if message == "Activities reported successfully" {
                                println("clearning stored data")
                                self.uploadString = ""
                            }
                        }
                    }
                }
            } else if httpResponse.statusCode == 400 {
                println("Bad Request")
            } else {
                println("Error is \(httpResponse.statusCode)")
            }
        }
    //println("finishing web upload")
    }

    
    func sendToWebservice(activityString: String,timestampString: String, latitudeString : String, longitudeString :String, speedString :String) {
        //let googleActivityType = convertToGoogleActivityType(activityString)
        var response: NSURLResponse?
        let deviceString = UIDevice.currentDevice().identifierForVendor.UUIDString
        let myUrl = NSURL(string: "http://ridesharing.cmu-tbank.com/reportActivity.php?userid=1&deviceid=\(deviceString)&activity=\(activityString)&currenttime=\(timestampString)&lat=\(latitudeString)&lng=\(longitudeString)&speed=\(speedString)")
        let request = NSMutableURLRequest(URL:myUrl!)
        request.HTTPMethod = "POST"
        //println(myUrl)
        var data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: nil) as NSData?
        if let httpResponse = response as? NSHTTPURLResponse {
            //OK
            if httpResponse.statusCode == 200 {
                //println("OK")
                if let json: NSDictionary = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary {
                    //println("stage 1 passed")
                    if let success = json["success"] as? Bool {
                        println(success)
                        if let message = json["message"] as? NSString {
                            println(message)
                            if message == "Activities reported successfully" {
                                println("YAYYY")
                            }
                        }
                    }
                }
            } else if httpResponse.statusCode == 400 {
                println("Bad Request")
            } else {
                println("Error is \(httpResponse.statusCode)")
            }
        }
    }
    
     func sendToServerBatch() {
        //var batteryLeft = ""
        //batteryLeft = "\(UIDevice.currentDevice().batteryLevel*100)"
        let myUrl = NSURL(string: "http://epiwork.hcii.cs.cmu.edu/~afsaneh/ChristianHybrid.php")
        let request = NSMutableURLRequest(URL:myUrl!)
        request.HTTPMethod = "POST"
        var postString = "\(UIDevice.currentDevice().identifierForVendor.UUIDString)"
        
        while offlineUpload.count > 0 {
        //for i in outputArray {
            // ["lat", "long", "UNKNOWN", "conf", "timestamp", "timezone", "speed", "batteryLeft"]
            println(offlineUpload[0])
            postString = postString + "Device ID=\(UIDevice.currentDevice().identifierForVendor.UUIDString), batteryLeft=\(offlineUpload[0][7]), longitude=\(offlineUpload[0][1]), latitude=\(offlineUpload[0][0]), type=\(offlineUpload[0][2]), confidence=\(offlineUpload[0][3]), timestamp=\(offlineUpload[0][4]), timezone=\(offlineUpload[0][5]),connection=\(offlineUpload[0][8])\n)"
            offlineUpload.removeAtIndex(0)
        }
        
        println(postString)
        request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            data, response, error in
            if error != nil {
                println("error=\(error)")
                return
            }
            var err: NSError?
            var myJSON = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error:&err) as? NSDictionary
        }
        println("data sent to server")
        task.resume()
    }
    
    func sendToServer(longitudeString: String, latitudeString: String, activityString: String, confidenceString: String, timestampString: String, timeZoneString: String, batteryChargeLeft :String, connectionString: String) {
        //let myUrl = NSURL(string: "http://cmu-tbank.com/~afsaneh@cmu-tbank.com/uploadScript.php")
        let myUrl = NSURL(string: "http://epiwork.hcii.cs.cmu.edu/~afsaneh/ChristianHybrid.php");
        println(myUrl)
        let request = NSMutableURLRequest(URL:myUrl!);
        request.HTTPMethod = "POST";
        //modify strings for formatting
        let stringBuffer = ", "
        let deviceString = UIDevice.currentDevice().identifierForVendor.UUIDString + stringBuffer
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        let batteryString = batteryChargeLeft + stringBuffer
        let longitudeString2 = longitudeString + stringBuffer
        let latitudeString2 = latitudeString + stringBuffer
        let activityString2 = activityString + stringBuffer
        let confidenceString2 = confidenceString + stringBuffer
        // Compose a query string
        let postString = "deviceID=\(deviceString)&batteryLeft=\(batteryString)&longitude=\(longitudeString2)&latitude=\(latitudeString2)&type=\(activityString2)&confidence=\(confidenceString2)&timestamp=\(timestampString)&timezone=\(timeZoneString)&connection=\(connectionString)";
        
        request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding);
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            data, response, error in
            if error != nil {
                println("error=\(error)")
                return
            }
            var err: NSError?
            var myJSON = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error:&err) as? NSDictionary
        }
        println("data sent to server")
        task.resume()
    }

    func batchStringBuilder(timestamp :String, latitude :String, longitude :String, activity :String, speed :String) -> String{
        //timestamp@lat@lng@googleActivity@speed is optional.
        var batchString = ""
        let batchBuffer = "@"
        let logEnder = "*"
        batchString = batchString + timestamp + batchBuffer
        batchString = batchString + latitude + batchBuffer
        batchString = batchString + longitude + batchBuffer
        batchString = batchString + activity + batchBuffer
        batchString = batchString + speed + logEnder
        return batchString
    }
    
    func printFromCoreData() {
        var request = NSFetchRequest(entityName: "tracking")
        //let appDelegate:AppDelegate = (UIApplication.sharedApplication().delegate as! AppDelegate)
        //let context:NSManagedObjectContext = appDelegate.managedObjectContext!
        let predicate = NSPredicate(format: "timestamp > %i", oldTime)
        var results :NSArray = managedObjectContext!.executeFetchRequest(request, error: nil)!
        for result in results {
            println(result)
        }
        oldTime = NSDate().timeIntervalSince1970
        
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }


    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "UbiCompLab-CMU.test1" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("test1", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("test1.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }

}

