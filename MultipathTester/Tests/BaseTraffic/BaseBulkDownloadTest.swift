//
//  BaseBulkDownloadTest.swift
//  MultipathTester
//
//  Created by Quentin De Coninck on 2/25/18.
//  Copyright © 2018 Universite Catholique de Louvain. All rights reserved.
//

import Foundation

class BaseBulkDownloadTest: BaseTest, Test {
    var rcvBytesDatas = [RcvBytesData]()
    
    func getDescription() -> String {
        let baseConfig = getProtocol().rawValue
        switch ipVer {
        case .v4:
            return baseConfig + " IPv4 Bulk Download of " + urlPath
        case .v6:
            return baseConfig + " IPv6 Bulk Download of " + urlPath
        default:
            return baseConfig + " Bulk Download of " + urlPath
        }
    }
    
    func getConfigDict() -> [String : Any] {
        return [
            "url": getURL(),
        ]
    }
    
    // Because QUIC cannot do GET without the https:// ...
    override func getURL() -> String {
        let url = super.getURL()
        return "https://" + url
    }
    
    override func getRunTime() -> Double {
        return 5.0
    }
    
    func getTestResult() -> TestResult {
        if success {
            errorMsg = String(format: "Completed in %.3f s", duration)
            shortResult = errorMsg
        } else {
            shortResult = "Failed"
        }
        return BulkDownloadResult(name: getDescription(), proto: getProtocol(), success: success, result: errorMsg, duration: duration, startTime: startTime, waitTime: waitTime, wifiBytesReceived: wifiBytesReceived, wifiBytesSent: wifiBytesSent, cellBytesReceived: cellBytesReceived, cellBytesSent: cellBytesSent, multipathService: runCfg.multipathServiceVar, rcvBytesDatas: rcvBytesDatas)
    }
}
