//
//  Memory.swift
//  elenbot
//
//  Created by Jascha Burmeister on 10.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

import Foundation
import AppKit

enum MemoryError: Error {
    case readFailed
    case readSizeMismatch
    case readDeallocateFailed
    case allocateFailed
    case deallocateFailed
    case writeFailed
    case protectFailed
}

class Memory {
    
    private let client: Client!

    init(client : Client) {
        self.client = client
    }
    
    deinit {
        
    }

    func read<T>(address: UInt64, type: T.Type, count: Int) throws -> Array<T> {
        
        var array: Array<T> = Array<T>()
        
        for i in 0...(count-1) {
            try array.append(read(address: address + UInt64(i * MemoryLayout<T>.stride) , type: type))
        }
        
        return array
    }
    
    func read<T>(address: UInt64, type: T.Type) throws -> T {
        var data: vm_offset_t = 0
        var dataCnt: mach_msg_type_number_t = 0;
        let read_result = vm_read(client.process.remoteTask, UInt(address), UInt(MemoryLayout<T>.size), &data, &dataCnt)
        if(read_result != KERN_SUCCESS) {
            print("Error reading address: \(read_result)")
            throw MemoryError.readFailed
        }
        let readDataPointer = UnsafeRawPointer(bitPattern: UInt(data))
        let value : T = readDataPointer!.assumingMemoryBound(to: T.self).pointee
        vm_deallocate(mach_task_self_, UInt(data), vm_size_t(dataCnt))
        return value
    }
    
    func write(address: UInt64, data: UnsafeRawPointer, size: UInt64) throws {
        let task = client.process.remoteTask
        let pointerValue = UInt(bitPattern: data)
        if(mach_vm_write(task, address, pointerValue, UInt32(size)) != 0) {
            throw MemoryError.writeFailed
        }
    }
    
    func allocate(size: UInt64, protection: vm_prot_t = VM_PROT_WRITE | VM_PROT_READ | VM_PROT_EXECUTE) throws -> UInt64 {
        let task = client.process.remoteTask
        var allocatedAddress = client.process.baseAddress
        if(mach_vm_allocate(task, &allocatedAddress, size, 1) != 0) {
            throw MemoryError.allocateFailed
        }
        if(mach_vm_protect(task, allocatedAddress, size, 0, protection) != 0) {
            throw MemoryError.allocateFailed
        }
        return allocatedAddress
    }
    
    func deallocate(address: UInt64, size: UInt64) throws {
        let task = client.process.remoteTask
        if(mach_vm_deallocate(task, address, size) != 0) {
            throw MemoryError.deallocateFailed
        }
    }
    
    func protect(address: UInt64, size: UInt64, protection: vm_prot_t, maximum: Bool = false) throws {
        let task = client.process.remoteTask
        let max: UInt32 = maximum ? 1 : 0
        if(mach_vm_protect(task, address, size, max, protection) != 0) {
            throw MemoryError.protectFailed
        }
    }
    
    private func getLowerBoundary(address : UInt64 ) -> UInt64 {
        if(address % 4096 == 0) {
            return address
        }else {
            return getLowerBoundary(address: address-1)
        }
    }
    
    private func getUpperBoundary(address : UInt64 ) -> UInt64 {
        return getUpperBoundaryRec(address: address + 4097)
    }
    
    private func getUpperBoundaryRec(address : UInt64 ) -> UInt64 {
        if(address % 4096 == 0) {
            return address
        }else {
            return getUpperBoundaryRec(address: address-1)
        }
    }

}

extension Data {
    public func hex() -> String {
        return self.map { String(format: "%02x", $0) }.joined().uppercased()
    }
}
