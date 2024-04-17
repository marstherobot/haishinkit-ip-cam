//
//  Created by Marius on 13.04.2024.
//  Copyright © 2024. All rights reserved.
//  

import os
import Network

//
// MARK: - NetworkConnectivityDelegate Protocol
//
public protocol NetworkConnectivityDelegate: AnyObject {
    func networkStatusChanged(online: Bool, connectivityStatus: String)
}

//
// MARK: - NetworkConnectivity
//
/// Class identifer for `NetworkConnectivity`.
public class NetworkConnectivity {

    //
    // MARK: - Static Constants
    //
    public static let shared = NetworkConnectivity()

    //
    // MARK: - Variables And Properties
    //
    private var online: Bool = false
    private var host: String = ""
    private var tcpStreamAlive: Bool = false

    //
    // MARK: - Variables And Properties
    //
    public weak var networkStatusDelegate: NetworkConnectivityDelegate?

    //
    // MARK: - Public Methods
    //

    public func setup(with hostURL: String) {

        if self.tcpStreamAlive {
            print("TCP Stream is already setup.")
        }

        self.host = hostURL

        guard hostURL.count > 0, self.validateHost(hostURL: hostURL) else {
            print("Error, invalid host.")
            return
        }

        if #available(iOS 12.0, OSX 10.14, *) {
            setupNWConnection()
        } else {
            print("Network framework only available for iOS 12 or macOS 10.14 or later.")
        }
    }

    //
    // MARK: - Private Methods
    //

    private func validateHost(hostURL: String) -> Bool {
        // TODO: Implement
        return true
    }

    @available(iOS 12.0, OSX 10.14, *)
    private func setupNWConnection() {
        print("Setting up nwConnection")
        
        let hostEndpoint = NWEndpoint.Host.init(self.host)
        let nwConnection = NWConnection(host: hostEndpoint, port: 80, using: .tcp)
        nwConnection.stateUpdateHandler = self.stateDidChange(to:)
        self.setupReceive(on: nwConnection)
        nwConnection.start(queue: DispatchQueue.global())
        
    }

    @available(iOS 12.0, OSX 10.14, *)
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            self.notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "setup")
            self.tcpStreamAlive = true
            break
        case .waiting:
            self.notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "waiting")
            self.tcpStreamAlive = true
            break
        case .ready:
            self.notifyDelegateOnChange(newStatusFlag: true, connectivityStatus: "ready")
            self.tcpStreamAlive = true
            break
        case .failed(let error):
            let errorMessage = "Error: \(error.localizedDescription)"
            self.notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: errorMessage)
            self.tcpStreamAlive = false
        case .cancelled:
            self.notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "cancelled")
            self.tcpStreamAlive = false
            self.setupNWConnection()
            break
        case .preparing:
            self.notifyDelegateOnChange(newStatusFlag: false, connectivityStatus: "preparing")
            self.tcpStreamAlive = true
        @unknown default:
            assertionFailure("unhandled case: \(state)")
        }
    }
    
    @available(iOS 12.0, OSX 10.14, *)
    private func setupReceive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, contentContext, isComplete, error) in
            // Read data off the stream
            if let data = data, !data.isEmpty {
                print("did receive \(data.count) bytes")
            }

            if isComplete {
                print("setupReceive: isComplete handle end of stream")
                connection.cancel()
                self.tcpStreamAlive = false
                self.setupNWConnection()

            } else if let error = error {
                print("setupReceive: error \(error.localizedDescription)")
                // TODO: Make sure that if the connection needs to be re-established here, it is.
            } else {
                self.setupReceive(on: connection)
            }
        }
    }

    @available(iOS 12.0, OSX 10.14, *)
    private func sendEndOfStream(connection: NWConnection) {
        connection.send(content: nil, contentContext: .defaultStream, isComplete: true, completion: .contentProcessed({ error in
            print("sendEndOfStream")
            if let error = error {
                //self.connectionDidFail(error: error)
                print("sendEndOfStream: error \(error.localizedDescription)")
            }
        }))
    }

    private func notifyDelegateOnChange(newStatusFlag: Bool, connectivityStatus: String) {
        if newStatusFlag != self.online {
            print("newStatusFlag: \(newStatusFlag) - connectivityStatus: \(connectivityStatus)")
            self.networkStatusDelegate?.networkStatusChanged(online: newStatusFlag, connectivityStatus: connectivityStatus)
            self.online = newStatusFlag
        } else {
            print("connectivityStatus: \(connectivityStatus)")
        }
    }

}
