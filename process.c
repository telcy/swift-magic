//
//  process.c
//  elenbot
//
//  Created by Jascha Burmeister on 11.02.19.
//  Copyright © 2019 Jascha Burmeister. All rights reserved.
//

#include "process.h"
#include <mach/mach.h>
#import <sys/proc_info.h>
#import <libproc.h>

int get_process_ids(pid_t* pids, int* size) {
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t _pids[numberOfProcesses];
    proc_listpids(PROC_ALL_PIDS, 0, pids, (int) sizeof(_pids));
    *size = numberOfProcesses;
    return 0;
}

int get_process_name(pid_t pid, char* buffer) {
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t pids[numberOfProcesses];
    bzero(pids, sizeof(pids));
    proc_listpids(PROC_ALL_PIDS, 0, pids, (int) sizeof(pids));
    for (int i = 0; i < numberOfProcesses; ++i) {
        
        if(pids[i] == pid) {
            proc_name(pids[i], buffer, 1024);
            return 0;
        }
        
    }
    
    return 0;
}

int get_remote_task(int pid, mach_port_t* task) {
    kern_return_t kern_return = task_for_pid(mach_task_self(), pid, task);
    if (kern_return != KERN_SUCCESS)
    {
        printf("task_for_pid() failed, error %d - %s\n", kern_return, mach_error_string(kern_return));
        return kern_return;
    }
    return 0;
}

int get_base_address(int pid, unsigned long long* base_address) {
    
    kern_return_t kern_return;
    mach_port_t task;
    
    kern_return = task_for_pid(mach_task_self(), pid, &task);
    if (kern_return != KERN_SUCCESS)
    {
        printf("task_for_pid() failed, error %d - %s\n", kern_return, mach_error_string(kern_return));
        return kern_return;
    }
    
    kern_return_t kret;
    vm_region_basic_info_data_t info;
    vm_size_t size;
    mach_port_t object_name;
    mach_msg_type_number_t count;
    vm_address_t firstRegionBegin = 0;
    vm_address_t lastRegionEnd = 0;
    vm_size_t fullSize = 0;
    count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_vm_address_t address = 1;
    int regionCount = 0;
    int flag = 0;
    while (flag == 0)
    {
        //Attempts to get the region info for given task
        kret = mach_vm_region(task, &address, (mach_vm_size_t *) &size, VM_REGION_BASIC_INFO, (vm_region_info_t) &info, &count, &object_name);
        if (kret == KERN_SUCCESS)
        {
            if (regionCount == 0)
            {
                firstRegionBegin = address;
                regionCount += 1;
            }
            fullSize += size;
            address += size;
        }
        else
            flag = 1;
    }
    lastRegionEnd = address;
    //    printf("Base Address: %lu\n",firstRegionBegin);
    //    printf("lastRegionEnd: %lu\n",lastRegionEnd);
    //    printf("fullSize: %lu\n",fullSize);
    
    
    *base_address = firstRegionBegin;
    
    return 0;

}

int get_image_symbol_address(mach_port_t task, const char *image_name, const char *symbol_name, unsigned long long* address) {
    *address = lorgnette_lookup_image(task, symbol_name, image_name);

    if(*address == 0) {
        return 1;
    } else {
        return 0;
    }

}
