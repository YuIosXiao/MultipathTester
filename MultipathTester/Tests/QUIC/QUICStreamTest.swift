//
//  QUICStreamTest.swift
//  QUICTester
//
//  Created by Quentin De Coninck on 1/22/18.
//  Copyright © 2018 Universite Catholique de Louvain. All rights reserved.
//

import UIKit
import Quictraffic
import Charts

class QUICStreamTest: BaseStreamTest {
    // MARK: Properties
    var maxPathID: UInt8
    
    // MARK: Properties for live graph
    var curUpDelays: [ChartDataEntry] = []
    var curDownDelays: [ChartDataEntry] = []
    
    init(ipVer: IPVersion, maxPathID: UInt8, runTime: Int, waitTime: Double, filePrefix: String) {
        self.maxPathID = maxPathID
        super.init(ipVer: ipVer, runTime: runTime, waitTime: waitTime, filePrefix: filePrefix)
        // Prepare the run configuration
        runCfg.maxPathIDVar = Int(maxPathID)
    }
    
    convenience init(ipVer: IPVersion, maxPathID: UInt8, runTime: Int, waitTime: Double) {
        let filePrefix = "quictraffic_stream_" + ipVer.rawValue
        self.init(ipVer: ipVer, maxPathID: maxPathID, runTime: runTime, waitTime: waitTime, filePrefix: filePrefix)
    }
    
    convenience init(ipVer: IPVersion, maxPathID: UInt8, runTime: Int) {
        self.init(ipVer: ipVer, maxPathID: maxPathID, runTime: runTime, waitTime: 3.0)
    }
    
    override func getProtocol() -> NetProtocol {
        if maxPathID > 0 {
            return .MPQUIC
        }
        return .QUIC
    }
    
    override func run() {
        super.run()
        let group = DispatchGroup()
        let queue = OperationQueue()
        var streamString: String? = ""
        group.enter()
        queue.addOperation {
            streamString = QuictrafficRun(self.runCfg)
            group.leave()
        }
        var res = group.wait(timeout: .now() + TimeInterval(0.1))
        while res == .timedOut {
            if stopped {
                break
            }
            res = group.wait(timeout: .now() + TimeInterval(0.1))
        }
        duration = Date().timeIntervalSince(startTime)
        wifiInfoEnd = InterfaceInfo.getInterfaceInfo(netInterface: .WiFi)
        cellInfoEnd = InterfaceInfo.getInterfaceInfo(netInterface: .Cellular)
        
        wifiBytesSent = wifiInfoEnd.bytesSent - wifiInfoStart.bytesSent
        wifiBytesReceived = wifiInfoEnd.bytesReceived - wifiInfoStart.bytesReceived
        cellBytesSent = cellInfoEnd.bytesSent - cellInfoStart.bytesSent
        cellBytesReceived = cellInfoEnd.bytesReceived - cellInfoStart.bytesReceived
        
        if stopped {
            errorMsg = "ERROR: Test stopped"
            
            return
        }
        
        let lines = streamString!.components(separatedBy: .newlines)
        errorMsg = lines[0]
        if lines.count < 3 {
            return
        }
        let splitted_up_line = lines[1].components(separatedBy: " ")
        let up_count = Int(splitted_up_line[1])!
        if up_count > 0 {
            var finalUpDelays = [DelayData]()
            for i in 2...up_count {
                let splitted_line = lines[i].components(separatedBy: ",")
                let ts = Double(splitted_line[0])! / 1000000000.0
                let delayUs = UInt64(splitted_line[1])!
                finalUpDelays.append(DelayData(time: ts, delayUs: delayUs))
            }
            // Set upDelays now, as it could have been set with getProgressDelay
            upDelays = finalUpDelays
        }
        let splitted_down_line = lines[up_count+2].components(separatedBy: " ")
        let down_count = Int(splitted_down_line[1])!
        if down_count > 0 {
            // Reset downDelays, as it could have been set with getProgressDelay
            var finalDownDelays = [DelayData]()
            for i in up_count+3...up_count+2+down_count {
                let splitted_line = lines[i].components(separatedBy: ",")
                let ts = Double(splitted_line[0])! / 1000000000.0
                let delayUs = UInt64(splitted_line[1])!
                finalDownDelays.append(DelayData(time: ts, delayUs: delayUs))
            }
            // Set downDelays now, as it could have been set with getProgressDelay
            downDelays = finalDownDelays
        }
        
        if errorMsg.contains("nil") || errorMsg.contains("deadline exceeded") || errorMsg.contains("PeerGoingAway") {
            success = true
        }
    }
    
    // MARK: Specific to that test
    override func getProgressDelays() -> ([DelayData], [DelayData]) {
        var upNewDelays = [DelayData]()
        var downNewDelays = [DelayData]()
        let delaysStr = QuictrafficGetStreamProgressResult(getNotifyID())
        let lines = delaysStr!.components(separatedBy: .newlines)
        if lines.count < 2 {
            return ([], [])
        }
        let splitted_up_line = lines[0].components(separatedBy: " ")
        let up_count = Int(splitted_up_line[1])!
        if up_count > 0 {
            for i in 1...up_count {
                let splitted_line = lines[i].components(separatedBy: ",")
                let ts = Double(splitted_line[0])! / 1000000000.0
                let delayUs = UInt64(splitted_line[1])!
                upNewDelays.append(DelayData(time: ts, delayUs: delayUs))
            }
        }
        let splitted_down_line = lines[up_count+1].components(separatedBy: " ")
        let down_count = Int(splitted_down_line[1])!
        if down_count > 0 {
            for i in up_count+2...up_count+1+down_count {
                let splitted_line = lines[i].components(separatedBy: ",")
                let ts = Double(splitted_line[0])! / 1000000000.0
                let delayUs = UInt64(splitted_line[1])!
                downNewDelays.append(DelayData(time: ts, delayUs: delayUs))
            }
        }
        // This offers more resilence in case something goes wrong
        upDelays += upNewDelays
        downDelays += downNewDelays
        
        return (upNewDelays, downNewDelays)
    }
    
    override func stopTraffic() {
        // Don't trust...
        let group = DispatchGroup()
        let queue = OperationQueue()
        group.enter()
        queue.addOperation {
            QuictrafficStopStream(self.getNotifyID())
            group.leave()
        }
        // Don't bother if we timeout in one second or not
        _ = group.wait(timeout: .now() + 1.0)
    }
    
    override func notifyReachability() {
        // Don't trust...
        let group = DispatchGroup()
        let queue = OperationQueue()
        group.enter()
        queue.addOperation {
            QuictrafficNotifyReachability(self.getNotifyID())
            group.leave()
        }
        // Don't bother if we timeout in 50 ms or not
        _ = group.wait(timeout: .now() + 0.05)
    }
    
    override func getChartData() -> ChartEntries? {
        let (newUpDelays, newDownDelays) = getProgressDelays()
        let newUpValues = newUpDelays.map { (d) -> ChartDataEntry in
            return ChartDataEntry(x: d.time, y: Double(d.delayUs) / 1000.0)
        }
        curUpDelays += newUpValues
        let newDownValues = newDownDelays.map { (d) -> ChartDataEntry in
            return ChartDataEntry(x: d.time, y: Double(d.delayUs) / 1000.0)
        }
        curDownDelays += newDownValues
        return MultiLineChartEntries(xLabel: "Time", yLabel: "Delay", dataLines: [
            "Upload delays (ms)": curUpDelays,
            "Download delays (ms)": curDownDelays,
        ])
    }
}

