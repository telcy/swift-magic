//
//  asm.c
//  elenbot
//
//  Created by Jascha Burmeister on 04.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

#include "asm.h"
#include <mach/mach.h>
#include <CoreServices/CoreServices.h>
#include "../Libs/keystone/keystone.h"

int asm_assemble_and_write(const char *assembly, mach_port_t task, unsigned long long address) {
    
    ks_arch arch = KS_ARCH_X86;
    int mode = KS_MODE_64;
    int syntax = KS_OPT_SYNTAX_INTEL;

    ks_engine *ks;
    ks_err err = KS_ERR_ARCH;
    size_t count;
    unsigned char *encode;
    size_t size;
    
    err = ks_open(arch, mode, &ks);
    if (err != KS_ERR_OK) {
        printf("ERROR: failed on ks_open(), quit\n");
        return -1;
    }
    
    if (syntax)
    ks_option(ks, KS_OPT_SYNTAX, syntax);

    if (ks_asm(ks, assembly, 0, &encode, &size, &count)) {
        printf("ERROR: failed on ks_asm() with count = %lu, error code = %u\n", count, ks_errno(ks));
        return -1;
    } else {       
        mach_vm_write(task, address, (vm_offset_t) encode, (mach_msg_type_size_t) size);
    }
    
    // NOTE: free encode after usage to avoid leaking memory
    ks_free(encode);
    
    // close Keystone instance when done
    ks_close(ks);
    
    return 0;
    
}

int asm_assemble(const char *assembly, const char *buffer, size_t *size) {
    
    ks_arch arch = KS_ARCH_X86;
    int mode = KS_MODE_64;
    int syntax = KS_OPT_SYNTAX_INTEL;

    ks_engine *ks;
    ks_err err = KS_ERR_ARCH;
    size_t encodeCount;
    unsigned char *encode;
    size_t encodeSize;
    
    err = ks_open(arch, mode, &ks);
    if (err != KS_ERR_OK) {
        printf("ERROR: failed on ks_open(), quit\n");
        return -1;
    }
    
    if (syntax)
        ks_option(ks, KS_OPT_SYNTAX, syntax);
    
    if (ks_asm(ks, assembly, 0, &encode, &encodeSize, &encodeCount)) {
        printf("ERROR: failed on ks_asm() with count = %lu, error code = %u\n", encodeCount, ks_errno(ks));
        return -1;
    } else {
        
        if(encodeSize > *size) {
            printf("asm_assemble: encodeSize bigger than buffer size");
            return -1;
        }
        
        *size = encodeSize;
        memcpy((void *)buffer, encode, encodeSize);
    }
    
    // NOTE: free encode after usage to avoid leaking memory
    ks_free(encode);
    
    // close Keystone instance when done
    ks_close(ks);
    
    return 0;
    
}
