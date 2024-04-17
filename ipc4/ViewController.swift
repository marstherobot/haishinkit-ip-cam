//
//  Created by Marius on 12.04.2024.
//  Copyright © 2024. All rights reserved.
//  

import UIKit
import HaishinKit
import AVFoundation
import Logboard

  
class ViewController: UIViewController {
    private let rtmpConnection = RTMPConnection()
    private let rtmpStream = RTMPStream(connection: RTMPConnection())
    private let previewView = MTHKView(frame: .zero)
    private let statusLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .orange
        setupPreview()
        setupStatusLabel()
        startCamera()
        
        LBLogger.with("com.haishinkit.HaishinKit").level = .trace
    }
    
    
    private func setupPreview() {
        print("[debug] :: \(#function)")
        previewView.videoGravity = .resizeAspectFill
        previewView.attachStream(rtmpStream)
        
        view.addSubview(previewView)
        previewView.frame = view.bounds
    }
    
    
    private func setupStatusLabel() {
        print("[debug] :: \(#function)")
        statusLabel.frame = CGRect(x: 20, y: view.bounds.height - 50, width: view.bounds.width - 40, height: 40)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
    }
    
    @objc func rtmpStatusHandler(_ notification: Notification) {
        let event = Event.from(notification)
        
        if let data = event.data as? [String: Any], let code = data["code"] as? String {
            print("RTMP status: \(code)")
            if code == "NetConnection.Connect.Success" {
                print("RTMP connection successful")
                rtmpStream.publish("stream")
            }
        }
    }
    
    private func startCamera() {
        print("[debug] :: \(#function)")
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(.playAndRecord, mode: .default, options: [])
        try! session.setActive(true)
        
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in }
//        rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in print(error) }
        
        let ip = getIPAddress()
        let streamAddress = "rtmp://\(ip):1935/stream"
        rtmpConnection.connect(streamAddress)
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)

//        rtmpStream.publish("stream")
        
        statusLabel.text = streamAddress
        statusLabel.backgroundColor = rtmpConnection.connected ? .green : .red
    }
    
    
    private func getIPAddress() -> String {
        print("[start of] :: \(#function)")
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        print("[end of] :: \(#function)")
        assert(nil != address)
        return address ?? "127.0.0.1"
    }
}

