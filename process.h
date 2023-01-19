//
//  process.h
//  elenbot
//
//  Created by Jascha Burmeister on 11.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

#ifndef process_h
#define process_h

#include <stdio.h>

int get_remote_task(int pid, mach_port_t* task);
int get_base_address(int pid, unsigned long long* base_address);
int get_process_ids(pid_t* pids, int* size);
int get_process_name(pid_t pid, char* buffer);
int get_image_symbol_address(mach_port_t task, const char *image_name, const char *symbol_name, unsigned long long* address);

#endif /* process_h */
