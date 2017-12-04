//
//  ConnectivityResult.swift
//  QUICTester
//
//  Created by Quentin De Coninck on 12/1/17.
//  Copyright © 2017 Universite Catholique de Louvain. All rights reserved.
//

import Foundation

class QUICConnectivityResult: NSObject, NSCoding, TestResult {
    // MARK: Properties
    var name: String
    var runTime: Double
    var success: Bool
    
    // MARK: Archiving Paths
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("quicConnectivityResults")
    
    // MARK: Types
    struct PropertyKey {
        static let name = "name"
        static let runTime = "runTime"
        static let success = "success"
    }
    
    // MARK: Initializers
    init?(name: String, runTime: Double, success: Bool) {
        self.name = name
        self.runTime = runTime
        self.success = success
    }
    
    // MARK: NSCoding
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(runTime, forKey: PropertyKey.runTime)
        aCoder.encode(success, forKey: PropertyKey.success)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObject(forKey: PropertyKey.name) as! String
        let runTime = aDecoder.decodeDouble(forKey: PropertyKey.runTime)
        let success = aDecoder.decodeBool(forKey: PropertyKey.success)
        
        self.init(name: name, runTime: runTime, success: success)
    }
    
    // MARK: TestResult
    func getDescription() -> String {
        return name
    }
    
    func getResult() -> String {
        if success {
            return "Succeeded in " + String(runTime) + " s"
        }
        return "Failed"
    }
}
