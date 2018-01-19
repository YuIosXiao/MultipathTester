//
//  ConnectivityResult.swift
//  QUICTester
//
//  Created by Quentin De Coninck on 12/1/17.
//  Copyright © 2017 Universite Catholique de Louvain. All rights reserved.
//

import Foundation
import Charts

class ConnectivityResult: BaseResult, TestResult {
    // MARK: Needed for Codable ability...
    static var type = TestResultType.connectivity
    
    // MARK: Collect URL
    static func getCollectURL() -> URL {
        return URL(string: "https://ns387496.ip-176-31-249.eu/connectivity/test/")!
    }

    // MARK: Archiving Paths
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("connectivityResults")
    
    // MARK: Initializers    
    convenience init(name: String, proto: NetProtocol, success: Bool, duration: Double, startTime: Date, waitTime: Double) {
        let result = "Succeeded in " + String(duration) + " s"
        self.init(name: name, proto: proto, success: success, result: result, duration: duration, startTime: startTime, waitTime: waitTime)
    }
    
    // MARK: TestResult
    static func getTestName() -> String {
        return "Connectivity"
    }
    
    static func getTestDescription() -> String {
        return "This test checks if a connection can be established"
    }
    
    func getChartData() -> [ChartEntries] {
        return []
    }
}
