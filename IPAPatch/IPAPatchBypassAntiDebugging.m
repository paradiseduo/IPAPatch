//
//  IPAPatchBypassAntiDebugging.m
//  IPAPatch
//
//  Created by wutian on 2017/3/23.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import "IPAPatchBypassAntiDebugging.h"
#import "fishhook.h"
#import "PatchSVC.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/syscall.h>
#import <mach-o/dyld.h>
#import <sys/termios.h>
#import <sys/ioctl.h>

#if !defined(PT_DENY_ATTACH)
#define PT_DENY_ATTACH 31
#endif
#if !defined(SYS_ptrace)
#define SYS_ptrace 26
#endif
#if !defined(SYS_syscall)
#define SYS_syscall 0
#endif
#if !defined(SYS_sysctl)
#define SYS_sysctl 202
#endif


// Sources:
// https://www.coredump.gr/articles/ios-anti-debugging-protections-part-1/
// https://www.coredump.gr/articles/ios-anti-debugging-protections-part-2/
// https://www.theiphonewiki.com/wiki/Bugging_Debuggers
// https://opensource.apple.com/source/Libc/Libc-167/gen.subproj/isatty.c.auto.html

// Bypassing PT_DENY_ATTACH technique

static void * (*original_dlsym)(void *, const char *);

int fake_ptrace(int _request, pid_t _pid, caddr_t _addr, int _data)
{
    NSLog(@"[AntiDebugBypass] catch ptrace and bypass.");
    return 0;
}

void * hooked_dlsym(void * __handle, const char * __symbol)
{
    if (strcmp(__symbol, "ptrace") == 0) {
        return &fake_ptrace;
    }
    
    return original_dlsym(__handle, __symbol);
}

static void disable_pt_deny_attach()
{
    original_dlsym = dlsym(RTLD_DEFAULT, "dlsym");
    rebind_symbols((struct rebinding[1]){{"dlsym", hooked_dlsym}}, 1);
}

// Bypassing sysctl debugger checking technique

static int (*original_sysctl)(int *, u_int, void *, size_t *, void *, size_t);

typedef struct kinfo_proc ipa_kinfo_proc;

int	hooked_sysctl(int * arg0, u_int arg1, void * arg2, size_t * arg3, void * arg4, size_t arg5)
{
    bool modify_needed = arg1 == 4 && arg0[0] == CTL_KERN && arg0[1] == KERN_PROC && arg0[2] == KERN_PROC_PID && arg2 && arg3 && (*arg3 == sizeof(ipa_kinfo_proc));
    
    if (modify_needed) {
        
        bool original_p_traced = false;
        {
            ipa_kinfo_proc * pointer = arg2;
            ipa_kinfo_proc info = *pointer;
            original_p_traced = (info.kp_proc.p_flag & P_TRACED) != 0;
        }
        
        int ret = original_sysctl(arg0, arg1, arg2, arg3, arg4, arg5);
        
        // keep P_TRACED if input value contains it
        if (!original_p_traced) {
            ipa_kinfo_proc * pointer = arg2;
            ipa_kinfo_proc info = *pointer;
            info.kp_proc.p_flag ^= P_TRACED;
            *pointer = info;
        }
        NSLog(@"[AntiDebugBypass] catch sysctl and bypass.");
        return ret;
        
    } else {
        return original_sysctl(arg0, arg1, arg2, arg3, arg4, arg5);
    }
}

static void disable_sysctl_debugger_checking()
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"options" ofType:@"plist"];
    NSMutableDictionary *dir = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    if (dir[@"USE_DOBBY"] == 0) { // 引入了Dobby之后sysctl不能fishhook，不然会崩溃
        original_sysctl = dlsym(RTLD_DEFAULT, "sysctl");
        rebind_symbols((struct rebinding[1]){{"sysctl", hooked_sysctl}}, 1);
    }
}

// Bypassing isatty debugger checking technique
static int (*orig_isatty)(int);

int fake_isatty(int number) {
    struct termios t;
    int ret = (tcgetattr(number, &t) != -1);
    if (ret) {
        NSLog(@"[AntiDebugBypass] catch isatty and bypass.");
        return 0;
    } else {
        return orig_isatty(number);
    }
}

static void disable_isatty_debugger_checking() {
    orig_isatty = dlsym(RTLD_DEFAULT, "isatty");
    rebind_symbols((struct rebinding[1]){{"isatty", fake_isatty}}, 1);
}

// Bypassing syscall debugger checking technique

static int (*orig_syscall)(int number, ...);
int fake_syscall(int number, ...) {
    int request;
    pid_t pid;
    caddr_t addr;
    int data;
    
    // fake stack, why use `char *` ? hah
    char *stack[8];
    
    va_list args;
    va_start(args, number);
    
    // get the origin stack args copy.(must >= origin stack args)
    memcpy(stack, args, 8 * 8);
    
    if (number == SYS_ptrace) {
        request = va_arg(args, int);
        pid = va_arg(args, pid_t);
        addr = va_arg(args, caddr_t);
        data = va_arg(args, int);
        va_end(args);
        if (request == PT_DENY_ATTACH) {
            NSLog(@"[AntiDebugBypass] catch 'syscall(SYS_ptrace, PT_DENY_ATTACH, 0, "
                  @"0, 0)' and bypass.");
            return 0;
        }
    } else {
        va_end(args);
    }
    
    // must understand the principle of `function call`. `parameter pass` is
    // before `switch to target` so, pass the whole `stack`, it just actually
    // faked an original stack. Do not pass a large structure,  will be replace with
    // a `hidden memcpy`.
    int x = orig_syscall(number, stack[0], stack[1], stack[2], stack[3], stack[4],
                         stack[5], stack[6], stack[7]);
    return x;
}

static void disable_syscall_debugger_checking() {
    orig_syscall = dlsym(RTLD_DEFAULT, "syscall");
    rebind_symbols((struct rebinding[1]){{"syscall", fake_syscall}}, 1);
}

// Bypassing exit debugger checking technique
static void (*orig_exit)(int);
void fake_exit(int status) {
    NSLog(@"fake exit");
}

static void disable_exit() {
    orig_exit = dlsym(RTLD_DEFAULT, "exit");
    rebind_symbols((struct rebinding[1]){{"exit", fake_exit}}, 1);
}

// Bypassing ioctl debugger checking technique
static int (*orig_ioctl)(int, unsigned long, ...);
int fake_ioctl(int fd, unsigned long cmd, ...) {
    int x = orig_ioctl(fd, cmd);
    if (!x && TIOCGWINSZ == cmd) {
        NSLog(@"[AntiDebugBypass] catch ioctl and bypass.");
        return -1;
    }
    return x;
}

static void disable_ioctl() {
    orig_ioctl = dlsym(RTLD_NEXT, "ioctl");
    rebind_symbols((struct rebinding[1]){{"ioctl", fake_ioctl}}, 1);
}


@implementation IPAPatchBypassAntiDebugging

+ (void)load
{
    if (isatty(1)) {
        disable_exit();
        disable_pt_deny_attach();
        disable_sysctl_debugger_checking();
        disable_syscall_debugger_checking();
        disable_isatty_debugger_checking();
//        kill_anti_debug(); //patch svc 0x80 anti debug
//        disable_ioctl();
    }
}

@end

