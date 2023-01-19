//
//  asm.h
//  elenbot
//
//  Created by Jascha Burmeister on 04.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

#ifndef asm_h
#define asm_h

#include <stdio.h>

int asm_assemble_and_write(const char *assembly, mach_port_t task, unsigned long long address);
int asm_assemble(const char *assembly, const char *buffer, size_t *size);

#endif /* asm_h */
