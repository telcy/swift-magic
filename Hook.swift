//
//  Hook.swift
//  elenbot
//
//  Created by Jascha Burmeister on 22.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

import Foundation

enum InjectionError: Error {
    case hookFailed
    case notFoundOpenGL
    case assembleFailed
    case injectAndExecuteFailed
}

class Hook {
    
    private let client: Client

    private var trampolineAddress: UInt64 = 0x0
    private var trampolineSize: UInt64 = 50
    private var addressInjection: UInt64 = 0x0
    private var addressReturn: UInt64 = 0x0
    private var injectionInUse: Bool = false
    
    
    init(client: Client) {
        self.client = client
    }
    
    func apply() throws {
        
        /*
        todo:
        - set old protection again for jump to codecave
        - maybe some unhook functionality
        done - fix 16 bytes alignment
        done - asm_assemble function to get bytes and size to calculate our codecave more accurately
        done - better calculation of self.codecaveWorkspaceAddress
        done - rename to trampoline
        done - nop left over intructions at overwrite
        done - add values to hook struct
        done - error handling
        done - write workspace clean function
        done - new hook structure
        */
        
        let baseAddress = client.process.baseAddress
        let remoteTask = client.process.remoteTask

        
        // HOOK CONFIG
        
        // HOOK A
        //        let overwrite_address: CUnsignedLongLong = baseAddress + 0x1e9808; // OK
        //        let overwrite_size: CUnsignedInt = 6
        //        let overridden_asm = """
        //            xorps xmm0, xmm0
        //            ucomiss xmm0, xmm1
        //        """
        
        // HOOK B
        //        let overwrite_address: CUnsignedLongLong = try client.process.getImageSymbolAddress(imageName: "OpenGL", symbolName: "CGLFlushDrawable") & 0xFFFFFFFF
        //        let overwrite_size: CUnsignedInt = 5
        //        let overridden_asm = """
        //            push ebp
        //            mov ebp, esp
        //            push esi
        //            push eax
        //        """
 
        // HOOK C
        let overwrite_address: UInt64 = (try client.process.getImageSymbolAddress(imageName: "OpenGL", symbolName: "CGLFlushDrawable") + 0x7FFF00000000 ) + 34
        let overwrite_size: UInt64 = 14
        let overridden_asm = """
        mov rdi, [rbx+0x1e80]
        cmp byte [rdi+0xad], 0x0
        """
        

        // HOOK D
        //        let overwrite_address: CUnsignedLongLong = baseAddress + 0x255ffa; // OK
        //        let overwrite_size: CUnsignedInt = 15
        //        let overridden_asm = """
        //        mov eax, r14d
        //        xorps xmm0, xmm0
        //        cvtsi2sd xmm0, rax
        //        mov byte [rbx+0x10], 0x4
        //        """
        
        
        // ALLOCATE SPACE
        
        trampolineAddress = try client.memory.allocate(size: trampolineSize)
        addressInjection = try client.memory.allocate(size: 8, protection: VM_PROT_WRITE | VM_PROT_READ)
        addressReturn = try client.memory.allocate(size: 8, protection: VM_PROT_WRITE | VM_PROT_READ)
        
        // BUILD TRAMPOLINE
        
        let asm = """

        push rax
        push rbx
        push rcx
        push rdx
        push rsi
        push rdi
        push rbp
        push rsp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15
        pushfq
        
        mov rdx, 0
        mov rax, rsp
        mov rcx, 16
        div rcx
        sub rsp, rdx
        sub rsp, 8
        push rdx
        
        mov rax, [\(addressInjection)]
        test rax, rax
        je .out
        
        mov rax, [\(addressInjection)]
        call rax
        
        mov [\(addressReturn)], rax
        
        mov rdx, \(addressInjection)
        mov rcx, 0
        mov [rdx], rcx
        
        .out:
        
        pop rdx
        add rsp, 8
        add rsp, rdx
        
        popfq
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rsp
        pop rbp
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
        pop rax
        
        \(overridden_asm)

        mov rax, \(Int64(overwrite_address) + 13)
        jmp rax
        """

        try inject(data: assemble(asm), address: trampolineAddress)
        
        // JUMP TO CODECAVE
        
        let leftoverNops = String(repeating: "nop;", count: Int(overwrite_size) - 14)
        let asmJump = """
            push rax
            mov rax, \(Int(trampolineAddress))
            jmp rax
            pop rax
            \(leftoverNops)
        """
        try client.memory.protect(address: overwrite_address, size: UInt64(overwrite_size), protection: VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_READ)
        try inject(data: assemble(asmJump), address: overwrite_address)
 
 
 
        print("addressOverwrite: \(overwrite_address)")
        print("addressTrampoline: \(trampolineAddress)")
        print("addressInjection: \(addressInjection)")
        
    }

    func injectAndExecute(_ asm: String) throws {
        
        while (injectionInUse) { usleep(5000) } //5ms
        injectionInUse = true
        
        defer {
            injectionInUse = false
        }

        // reset return value
        //var reset: UInt32 = 0x0
        //try client.memory.write(address: addressReturn, data: &reset, size: 4)
        
        // assemble and inject
        let bytes = try assemble(asm)
        var address = try client.memory.allocate(size: UInt64(bytes.count))
        try inject(data: bytes, address: UInt64(address))

        // update addressInjection
        //print("injected code address: \(address)")
        try client.memory.write(address: addressInjection, data: &address, size: 8)
        
        // wait while executing
        while (try client.memory.read(address: addressInjection, type: UInt64.self) > 0) {
            usleep(5000)//5ms
        }
        
        // deallocate
        try client.memory.deallocate(address: UInt64(address), size: UInt64(bytes.count))
        
        // grab return value
        //var retValue: UInt32 = = try client.memory.read(address: addressReturn, type: UInt32.self)

        //return retValue
    }
    
    private func assemble(_ asm: String) throws -> Array<CChar> {
        var size = 1000
        var buffer = [CChar](repeating: 90, count: size)
        if(asm_assemble(asm, &buffer, &size) != 0) {
            throw InjectionError.assembleFailed
        }
        return Array(buffer.prefix(size))
    }

    private func inject(data: Array<CChar>, address: UInt64) throws {
        let bytesPointer = UnsafeRawPointer(data)
        try client.memory.write(address: address, data: bytesPointer, size: UInt64(data.count))
    }

    
}
