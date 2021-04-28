//
//  PatchSVC.c
//  IPAPatch-DummyApp
//
//  Created by ParadiseDuo on 2021/4/28.
//  Copyright © 2021 ParadiseDuo. All rights reserved.
//

#include "PatchSVC.h"
#include <mach-o/dyld.h>
#include <string.h>
#include <malloc/_malloc.h>
#include <sys/mman.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t,
                                     mach_vm_size_t, mach_vm_address_t,
                                     mach_vm_size_t *);
kern_return_t mach_vm_remap(vm_map_t, mach_vm_address_t *, mach_vm_size_t,
                            mach_vm_offset_t, int, vm_map_t, mach_vm_address_t,
                            boolean_t, vm_prot_t *, vm_prot_t *, vm_inherit_t);
kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t,
                            mach_msg_type_number_t);
kern_return_t mach_vm_allocate(vm_map_t, mach_vm_address_t *, mach_vm_size_t, int);
kern_return_t mach_vm_deallocate(vm_map_t, mach_vm_address_t, mach_vm_size_t);
kern_return_t mach_vm_region(vm_map_t, mach_vm_address_t *, mach_vm_size_t *,
                             vm_region_flavor_t, vm_region_info_t,
                             mach_msg_type_number_t *, mach_port_t *);


struct segmentRange {
    unsigned long long start;
    unsigned long long end;
};

char* hex_dump(void* target_addr, uint64_t size){
    uint64_t hex_buffer_size = size*3 + 1;
    char* hex_buffer = (char*)malloc((unsigned long)hex_buffer_size);
    memset(hex_buffer, 0x0, hex_buffer_size);

    uint8_t* p = (uint8_t*)target_addr;
    char* q = hex_buffer;

    for(int  i = 0; i < size ;i++ ){
        sprintf(q, "%02X ", *p);
        q += 3;
        p ++;
    };
    return hex_buffer;
}

void getTextSegmentAddr(struct segmentRange *textSegRange){

    int offset = 0;
    struct mach_header_64* header = (struct mach_header_64*)_dyld_get_image_header(0);

    if(header->magic != MH_MAGIC_64) {
        return ;
    }

    offset = sizeof(struct mach_header_64);
    int ncmds = header->ncmds;

    while(ncmds--) {
        /* go through all load command to find __TEXT segment*/
        struct load_command * lcp = (struct load_command *)((uint8_t*)header + offset);
        offset += lcp->cmdsize;

        if(lcp->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * curSegment = (struct segment_command_64 *)lcp;
            struct section_64* curSection = (struct section_64*)((uint8_t*)curSegment + sizeof(struct segment_command_64));

            // check current section of segment is __TEXT?
            if(!strcmp(curSection->segname, "__TEXT") && !strcmp(curSection->sectname, "__text")){
                uint64_t memAddr = curSection->addr;
                textSegRange->start = memAddr + _dyld_get_image_vmaddr_slide(0);
                textSegRange->end = textSegRange->start + curSection->size;
                break;
            }

        }
    }
    return ;
}

void* lookup_ptrace_svc(void * target_addr, uint64_t size) {
    uint8_t * p = (uint8_t *)target_addr;
    for (int i = 0; i < size; ++i) {
        /*
         mov       x16, #0x1a -> 0xd2800350
         svc        #0x80 -> 0xd4001001
         */
        if (*((uint32_t*)p) == 0xd2800350 && *((uint32_t*)p+1) == 0xd4001001) {
            return p;
        }
        p++;
    }
    return NULL;
}

bool patch_code(void* patch_addr, uint8_t* patch_data, int patch_data_size) {
    // init value
    kern_return_t kret;
    task_t self_task = (task_t)mach_task_self();
    
    void* target_addr = patch_addr;
    
    // 1. get target address page and patch offset
    unsigned long page_start = (unsigned long) (target_addr) & ~PAGE_MASK;
    unsigned long patch_offset = (unsigned long)target_addr - page_start;
    // map new page for patch
    void *new_page = (void *)mmap(NULL, PAGE_SIZE, 0x1 | 0x2, 0x1000 | 0x0001, -1, 0);
    if (!new_page ){
        return false;
    }
    kret = (kern_return_t)vm_copy(self_task, (unsigned long)page_start, PAGE_SIZE, (vm_address_t) new_page);
    if (kret != KERN_SUCCESS){
        return false;
    }
    
    // 2. start patch
    /*
     nop -> {0x1f, 0x20, 0x03, 0xd5}
     ret -> {0xc0, 0x03, 0x5f, 0xd6}
    */
    // char patch_ins_data[4] = {0x1f, 0x20, 0x03, 0xd5};
    // mach_vm_write(task_self, (vm_address_t)(new+patch_offset), patch_ret_ins_data, 4);
    memcpy((void *)((uint64_t)new_page+patch_offset), patch_data, patch_data_size);
    
    // set back to r-x, if remove this line, mach_vm_remap will crash.
    int _ = (int)mprotect(new_page, PAGE_SIZE, PROT_READ | PROT_EXEC);
    
    // remap
    vm_prot_t prot;
    vm_inherit_t inherit;
    
    // get page info
    vm_address_t region = (vm_address_t) page_start;
    vm_size_t region_len = 0;
    struct vm_region_submap_short_info_64 vm_info;
    mach_msg_type_number_t info_count = VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
    natural_t max_depth = 99999;
    kret = (kern_return_t)vm_region_recurse_64(self_task, &region, &region_len,
                                            &max_depth,
                                            (vm_region_recurse_info_t) &vm_info,
                                            &info_count);
    if (kret != KERN_SUCCESS){
        return false;
    }
    prot = vm_info.protection & (PROT_READ | PROT_WRITE | PROT_EXEC);
    inherit = vm_info.inheritance;
    
    vm_prot_t c;
    vm_prot_t m;
    mach_vm_address_t target = (mach_vm_address_t)page_start;
    
    kret = (kern_return_t)mach_vm_remap(self_task, &target, PAGE_SIZE, 0,
                                    VM_FLAGS_OVERWRITE, self_task,
                                    (mach_vm_address_t) new_page, true,
                                    &c, &m, inherit);
    if (kret != KERN_SUCCESS){
        return false;
    }
    
    // clear cache
    void* clear_start_ = (void*)(page_start + patch_offset);
    sys_icache_invalidate(clear_start_, 4);
    sys_dcache_flush(clear_start_, 4);
    return true;
};

void kill_anti_debug() {

    struct segmentRange textSegRange;
    getTextSegmentAddr(&textSegRange);
    void* ptrace_svc_p = lookup_ptrace_svc((void*)textSegRange.start, textSegRange.end-textSegRange.start);
    if (!ptrace_svc_p) {
        printf("[-] not found ptrace svc \n");
        return;
    }

    printf("[+] found ptrace svc # address=%p\n", ptrace_svc_p);

    char* ptrace_bytes = hex_dump((void*)ptrace_svc_p, 8);

    printf("[+] read ptrace svc ins address:%p size:0x%x inst_bytes:%s \n", ptrace_svc_p, 8, ptrace_bytes);
    free(ptrace_bytes);

    printf("[*] start to ptach ptrace svc to ret \n");


    uint8_t patch_ins_data[4] = {0x1f, 0x20, 0x03, 0xd5};

    patch_code(ptrace_svc_p+4, patch_ins_data , 4);
    printf("[*] ptach ptrace svc to nop done, read new value \n");

    ptrace_bytes = hex_dump((void*)ptrace_svc_p, 8);
    printf("[+] read ptrace svc ins address:%p size:0x%x inst_bytes:%s \n", ptrace_svc_p, 8, ptrace_bytes);
    free(ptrace_bytes);

}
