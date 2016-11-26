//
//  DataPacket.swift
//  Migla
//
//  Created by Admin on 2016-08-02.
//  Copyright © 2016 Migla. All rights reserved.
//

import Foundation

public struct DataPacket: CustomStringConvertible {
    
    // MARK: Types
    
    public typealias Body = Dictionary<String, AnyObject>
    public typealias PayloadInfo = Dictionary<String, AnyObject>
    
    
    // MARK: Properties
    
    static let protocolVersion: UInt = 7
    
    var id: Int64
    var type: String
    var body: Body
    var payload: Stream?
    var payloadSize: Int?
    var payloadInfo: PayloadInfo?
    
    public var description: String {
        do {
            let bytes = try self.serialize(options: .prettyPrinted)
            let str = String(bytes: bytes, encoding: String.Encoding.utf8)
            if let str = str {
                return str
            }
            else {
                return "\(bytes)"
            }
        }
        catch {
            return "Could not serialize data packet: \(error)"
        }
        
    }
    
    
    // MARK: Init / Deinit
    
    init(type: String, body: Body) {
        let id = Int64(Date().timeIntervalSince1970 * 1000)
        self.init(id: id, type: type, body: body)
    }
    
    init?(json: inout [UInt8]) {
        let data = Data(bytesNoCopy: &json, count: json.count, deallocator: .none)
        self.init(data: data)
    }
    
    init?(data: Data) {
        let deserializedObj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
        guard let obj = deserializedObj as? [String: AnyObject] else { return nil }
        guard let id = obj["id"] as? NSNumber else { return nil }
        guard let type = obj["type"] as? String else { return nil }
        guard let body = obj["body"] as? Body else { return nil }
        
        self.init(id: id.int64Value, type: type, body: body)
    }
    
    private init(id: Int64, type: String, body: Body) {
        self.id = id
        self.type = type
        self.body = body
    }
    
    
    // MARK: Public methods
    
    func serialize() throws -> [UInt8] {
        return try serialize(options: JSONSerialization.WritingOptions())
    }
    
    func serialize(options: JSONSerialization.WritingOptions) throws -> [UInt8] {
        let dict: [String: AnyObject] = [
            "id": NSNumber(value: self.id),
            "type": self.type as AnyObject,
            "body": self.body as AnyObject
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: options)
        var bytes = [UInt8](data)
        bytes.append(UInt8(ascii: "\n"))
        return bytes
    }
}



// MARK: - Identity packet

extension DataPacket {
    
    // MARK: Types
    
    public enum IdentityProperty: String {
        case deviceId = "deviceId"
        case deviceName = "deviceName"
        case deviceType = "deviceType"
        case incomingCapabilities = "incomingCapabilities"
        case outgoingCapabilities = "outgoingCapabilities"
        case protocolVersion = "protocolVersion"
        case tcpPort = "tcpPort"
    }
    
    public enum IdentityError: Error {
        case wrongType
        case invalidDeviceId
        case invalidDeviceName
        case invalidDeviceType
        case invalidProtocolVersion
        case invalidTCPPort
        case invalidIncomingCapabilities
        case invalidOutgoingCapabilities
    }
    
    
    // MARK: Properties
    
    public static let identityPacketType = "kdeconnect.identity"
    
    
    // MARK: Public static methods
    
    public static func identityPacket(config: HostConfiguration) -> DataPacket {
        return identityPacket(additionalProperties: nil, config: config)
    }
    
    public static func identityPacket(additionalProperties:DataPacket.Body?, config: HostConfiguration) -> DataPacket {
        var body: Body = [
            IdentityProperty.deviceId.rawValue: config.hostDeviceId as AnyObject,
            IdentityProperty.deviceName.rawValue: config.hostDeviceName as AnyObject,
            IdentityProperty.deviceType.rawValue: config.hostDeviceType.rawValue as AnyObject,
            IdentityProperty.protocolVersion.rawValue: NSNumber(value: DataPacket.protocolVersion),
            IdentityProperty.outgoingCapabilities.rawValue: Array(config.outgoingCapabilities) as AnyObject,
            IdentityProperty.incomingCapabilities.rawValue: Array(config.incomingCapabilities) as AnyObject
        ]
        if let properties = additionalProperties {
            for (key, value) in properties {
                body[key] = value
            }
        }
        let packet = DataPacket(type: identityPacketType, body: body)
        return packet
    }
    
    
    // MARK: Public methods
    
    public func getDeviceId() throws -> String {
        try self.validateIdentityType()
        guard let deviceId = body[IdentityProperty.deviceId.rawValue] as? String else { throw IdentityError.invalidDeviceId }
        return deviceId
    }
    
    public func getDeviceName() throws -> String {
        try self.validateIdentityType()
        guard let deviceName = body[IdentityProperty.deviceName.rawValue] as? String else { throw IdentityError.invalidDeviceName }
        return deviceName
    }
    
    public func getDeviceType() throws -> String {
        try self.validateIdentityType()
        guard let deviceType = body[IdentityProperty.deviceType.rawValue] as? String else { throw IdentityError.invalidDeviceType }
        return deviceType
    }
    
    public func getProtocolVersion() throws -> UInt {
        try self.validateIdentityType()
        guard let protocolVersion = body[IdentityProperty.protocolVersion.rawValue] as? NSNumber else { throw IdentityError.invalidProtocolVersion }
        return protocolVersion.uintValue
    }
    
    public func getTCPPort() throws -> UInt16 {
        try self.validateIdentityType()
        guard let tcpPort = body[IdentityProperty.tcpPort.rawValue] as? NSNumber else { throw IdentityError.invalidTCPPort }
        return tcpPort.uint16Value
    }
    
    public func getIncomingCapabilities() throws -> Set<Service.Capability> {
        try self.validateIdentityType()
        guard let capabilities = body[IdentityProperty.incomingCapabilities.rawValue] as? [String] else { throw IdentityError.invalidIncomingCapabilities }
        return Set(capabilities)
    }
    
    public func getOutgoingCapabilities() throws -> Set<Service.Capability> {
        try self.validateIdentityType()
        guard let capabilities = body[IdentityProperty.outgoingCapabilities.rawValue] as? [String] else { throw IdentityError.invalidOutgoingCapabilities }
        return Set(capabilities)
    }
    
    public func validateIdentityType() throws {
        guard type == DataPacket.identityPacketType else { throw IdentityError.wrongType }
    }
}