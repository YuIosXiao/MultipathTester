//
//  TCPPerfTest.swift
//  MultipathTester
//
//  Created by Quentin De Coninck on 2/28/18.
//  Copyright © 2018 Universite Catholique de Louvain. All rights reserved.
//

import Foundation

class TCPPerfTest: BasePerfTest {
    var multipath: Bool
    var endTime = Date()
    var stop = false
    var counter = 0
    
    init(ipVer: IPVersion, multipath: Bool) {
        self.multipath = multipath
        
        let filePrefix = "quictraffic_qperf_" + ipVer.rawValue
        super.init(ipVer: ipVer, filePrefix: filePrefix, waitTime: 3.0)
    }
    
    override func getProtocol() -> NetProtocol {
        if multipath {
            return .MPTCP
        }
        return .TCP
    }
    
    // REMOVE ME
    override func getTestServerHostname() -> String {
        return "mptcp4.qdeconinck.be"
    }
    
    func setupMetaConnection(session: URLSession) -> (URLSessionStreamTask, UInt64, Bool) {
        let group = DispatchGroup()
        group.enter()
        var ok = false
        let metaConn = session.streamTask(withHostName: self.getTestServerHostname(), port: Int(self.port))
        metaConn.resume()
        let connID: UInt64 = UInt64(arc4random_uniform(UInt32.max)) * (UInt64(UInt32.max) + 1) + UInt64(arc4random_uniform(UInt32.max))
        let runTimeNs = UInt64(self.runCfg.runTimeVar * 1_000_000_000)
        // [Length(4)|'M'(1)|{'U' or 'D'(1)}|connID(8)|runTimeNs(8)]
        let data = NSMutableData()
        Binary.putUInt32(18, to: data)
        Binary.putUInt8(77, to: data) // 'M'
        // Only do upload so far, download will be implemented later
        Binary.putUInt8(85, to: data) // 'U'
        Binary.putUInt64(connID, to: data)
        Binary.putUInt64(runTimeNs, to: data)
        
        metaConn.write(data as Data, timeout: 10.0, completionHandler: { (error) in
            if let err = error {
                print("An write error occurred", err)
            }
        })
        metaConn.readData(ofMinLength: 1, maxLength: 1, timeout: 10.0) { (data, atEOF, error) in
            defer { group.leave() }
            guard error == nil && data != nil else {
                //self.errorMsg = "\(String(describing: error))"
                print("\(String(describing: error))")
                return
            }
            // ['1'(1)]
            let bytes = [UInt8](data!)
            guard bytes[0] == 49 else {
                print("Unexpected answer on meta conn", bytes[0])
                return
            }
            
            ok = true
        }
        group.wait()
        return (metaConn, connID, ok)
    }
    
    func setupDataConnection(session: URLSession, connID: UInt64) -> (URLSessionStreamTask, Bool) {
        let group = DispatchGroup()
        group.enter()
        var ok = false
        let upConn = session.streamTask(withHostName: self.getTestServerHostname(), port: Int(self.port))
        upConn.resume()
        // [Length(4)|'D'(1)|connID(8)]
        let data = NSMutableData()
        Binary.putUInt32(9, to: data)
        Binary.putUInt8(68, to: data) // 'D'
        Binary.putUInt64(connID, to: data)
        
        upConn.write(data as Data, timeout: 10.0, completionHandler: { (error) in
            if let err = error {
                print("An write error occurred", err)
                group.leave()
                return
            }
            ok = true
            group.leave()
        })
        group.wait()
        return (upConn, ok)
    }
    
    override func run() -> [String : Any] {
        _ = super.run()
        intervals = [IntervalData]()
        
        let config = URLSessionConfiguration.ephemeral
        // TODO Multipath service
        if multipath {
            config.multipathServiceType = URLSessionConfiguration.MultipathServiceType.interactive
        }
        
        let session = URLSession(configuration: config)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            defer { group.leave() }
            let (metaConn, connID, okMeta) = self.setupMetaConnection(session: session)
            guard okMeta else { return }
            let (dataConn, okData) = self.setupDataConnection(session: session, connID: connID)
            guard okData else { return }
            self.endTime = Date().addingTimeInterval(TimeInterval(self.runCfg.runTimeVar))
            print(self.endTime.timeIntervalSinceNow)
            while Date().compare(self.endTime) == .orderedAscending && !self.stop {
                // Important to avoid overloading read calls
                let group2 = DispatchGroup()
                group2.enter()
                dataConn.resume()
                let stringData = String(repeating: "0123456789", count: 4000)
                dataConn.write(stringData.data(using: .utf8)!, timeout: self.endTime.timeIntervalSinceNow, completionHandler: { (error) in
                    defer { group2.leave() }
                    if let err = error {
                        print("An write error occurred", err)
                    }
                })
                group2.wait()
            }
        }
        
        var slen: socklen_t = socklen_t(MemoryLayout<tcp_connection_info>.size)
        var tcpi = tcp_connection_info()
        var res: DispatchTimeoutResult = .timedOut
        let ips = ipsOf(hostname: getTestServerHostname())
        // Don't take the meta conn
        var fd = findTCPFileDescriptor(expectedIPs: ips, expectedPort: Int16(port), startAt: 5)
        if (fd < 0) {
            while (res == .timedOut && fd < 0) {
                res = group.wait(timeout: DispatchTime.now() + 0.01)
                print("We missed it once, try again...")
                // Retry, we might have missed the good one thinking it's and old one
                fd = findTCPFileDescriptor(expectedIPs: ips, expectedPort: Int16(port), startAt: 5)
            }
        }
        print("FD is \(fd)")
        
        var tcpInfos = [Any]()
        var lastInterval = Date()
        var transferredLastSecond: UInt64 = 0
        var retransmittedLastSecond: UInt64 = 0
        
        while (res == .timedOut) {
            res = group.wait(timeout: DispatchTime.now() + (TimeInterval(runCfg.logPeriodMsVar) / 1000.0))
            if res == .success {
                break
            }
            let timeInfo = Date().timeIntervalSince1970
            let err2 = getsockopt(fd, IPPROTO_TCP, TCP_CONNECTION_INFO, &tcpi, &slen)
            if err2 != 0 {
                //print(err2, errno, ENOPROTOOPT)
                if multipath {
                    let dict = IOCTL.getMPTCPInfoClean(fd)
                    if dict != nil {
                        print(dict!)
                    }
                } else {
                    fd = findTCPFileDescriptor(expectedIPs: ips, expectedPort: Int16(port), startAt: 5)
                    print(fd)
                }
                
            } else {
                let tcpInfo = tcpInfoToDict(time: timeInfo, tcpi: tcpi)
                tcpInfos.append(tcpInfo)
                let now = Date()
                if cwinData["Congestion Window"] == nil {
                    cwinData["Congestion Window"] = [CWinData]()
                }
                cwinData["Congestion Window"]!.append(CWinData(time: timeInfo, cwin: UInt64(tcpInfo["tcpi_snd_cwnd"] as! UInt32)))
                if now.timeIntervalSince(lastInterval) > (1.0 - TimeInterval(runCfg.logPeriodMsVar) / 1000.0) {
                    let transferredNow = tcpInfo["tcpi_txbytes"] as! UInt64
                    let retransmittedNow = tcpInfo["tcpi_txretransmitbytes"] as! UInt64
                    let nxtCounter = counter + 1
                    let interval = IntervalData(interval: "\(counter)-\(nxtCounter)", transferredLastSecond: transferredNow - transferredLastSecond, globalBandwidth: transferredNow / UInt64(nxtCounter), retransmittedLastSecond: retransmittedNow - retransmittedLastSecond)
                    intervals.append(interval)
                    transferredLastSecond = transferredNow
                    retransmittedLastSecond = retransmittedNow
                    lastInterval = now
                    counter += 1
                }
            }
            res = group.wait(timeout: DispatchTime.now())
        }
        
        // Go for a last TCP info before closing
        var totalRetrans: UInt64 = 0
        var totalSent: UInt64 = 0
        let timeInfo = Date().timeIntervalSince1970
        let err2 = getsockopt(fd, IPPROTO_TCP, TCP_CONNECTION_INFO, &tcpi, &slen)
        if err2 != 0 {
            print(err2, errno, ENOPROTOOPT)
        } else {
            let tcpInfo = tcpInfoToDict(time: timeInfo, tcpi: tcpi)
            tcpInfos.append(tcpInfo)
            totalSent = tcpInfo["tcpi_txbytes"] as! UInt64
            totalRetrans = tcpInfo["tcpi_txretransmitbytes"] as! UInt64
        }
        
        print(tcpInfos)
        print(intervals)

        let elapsed = Date().timeIntervalSince(startTime)
        wifiInfoEnd = InterfaceInfo.getInterfaceInfo(netInterface: .WiFi)
        cellInfoEnd = InterfaceInfo.getInterfaceInfo(netInterface: .Cellular)
        print(errorMsg)
        var success = false
        if errorMsg.contains("Operation timed out") {
            if intervals.count > 0 {
                success = true
            } else {
                self.errorMsg = self.errorMsg + " (could not collect metadata)"
            }
        }
        
        result = [
            "intervals": intervals,
            "duration": String(format: "%.9f", elapsed),
            "success": success,
            "total_retrans": totalRetrans,
            "total_sent": totalSent,
            "wifi_bytes_sent": wifiInfoEnd.bytesSent - wifiInfoStart.bytesSent,
            "wifi_bytes_received": wifiInfoEnd.bytesReceived - wifiInfoStart.bytesReceived,
            "cell_bytes_sent": cellInfoEnd.bytesSent - cellInfoStart.bytesSent,
            "cell_bytes_received": cellInfoEnd.bytesReceived - cellInfoStart.bytesReceived,
        ]
        return result
    }
}
