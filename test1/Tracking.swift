//
//  Tracking.swift
//  test1
//
//  Created by Ivy Chung on 6/8/15.
//  Copyright (c) 2015 Patrick Chang. All rights reserved.
//

import Foundation
import CoreData

class Tracking: NSManagedObject {

    @NSManaged var timestamp: String
    @NSManaged var timezone: String
    @NSManaged var latitude: String
    @NSManaged var longitude: String
    @NSManaged var activity: String
    @NSManaged var confidence: String

}
