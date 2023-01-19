//
//  Process.swift
//  elenbot
//
//  Created by Jascha Burmeister on 19.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

import Foundation

enum ProcessError: Error {
    case getRemoteTaskFailed
    case getBaseAddressFailed
    case getProcessNameByPidFailed
    case getProcessIdsFailed
    case getImageSymbolFailed
}

class Process {
    
    private let client: Client
    public private(set) var remoteTask : mach_port_t
    public private(set) var baseAddress : CUnsignedLongLong
    
    init(client: Client) throws {
        self.client = client
        self.remoteTask = try Process.getRemoteTask(client.pid)
        self.baseAddress = try Process.getBaseAddress(client.pid)
    }
    
    static func getProcessIds() throws -> Array<pid_t> {
        var buffer = [pid_t](repeating: 0, count: 5000)
        var size : Int32  = 0
        if(get_process_ids(&buffer, &size) != 0) {
            throw ProcessError.getProcessIdsFailed
        }
        let arr  = convert(length: Int(size), data: &buffer, pid_t.self)
        return arr
    }
    
    static func getProcessNameByPid(_ pid : pid_t) throws -> String {
        var buffer = [CChar](repeating: 0, count: 1024)
        if(get_process_name(pid, &buffer) != 0) {
            throw ProcessError.getProcessNameByPidFailed
        }

        return String(cString: buffer)
    }
    
    static func getRemoteTask(_ pid : pid_t) throws -> mach_port_t {
        var task: mach_port_t = 0
        if(get_remote_task(pid, &task) != 0) {
            throw ProcessError.getRemoteTaskFailed
        }
        return task
    }
    
    static func getBaseAddress(_ pid : pid_t) throws -> UInt64  {
        var address: UInt64 = 0x0
        if(get_base_address(pid, &address) != 0) {
            throw ProcessError.getBaseAddressFailed
        }
        return address
    }
    
    func getImageSymbolAddress(imageName: String, symbolName: String) throws -> UInt64 {
        var address: UInt64 = 0x0
        if(get_image_symbol_address(remoteTask, imageName, symbolName, &address) != 0) {
            throw ProcessError.getImageSymbolFailed
        }
        return address
    }
    
    private static func convert<T>(length: Int, data: UnsafeMutablePointer<pid_t>, _: T.Type) -> [T] {
        let numItems = length/MemoryLayout<T>.stride
        let buffer = data.withMemoryRebound(to: T.self, capacity: numItems) {
            UnsafeBufferPointer(start: $0, count: numItems)
        }
        return Array(buffer)
    }
    
    
}
