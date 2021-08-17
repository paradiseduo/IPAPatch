//
//  IPAPatchEntry.m
//  IPAPatch
//
//  Created by wutian on 2017/3/17.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import "IPAPatchEntry.h"
#import "Tools.h"
#import "PermissionCheck.h"

#define BUNDLEID @"xxxxxxx"

@implementation IPAPatchEntry

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 使用passHTTPS3时请不要调用显示FLEX，FLEX抓端口的原理跟passHTTPS3的原理一样，因此代码会出现冲突（NSURLProtocol只能存在一个）。
        [Tools showFLEXDelayBy:5];
        
        // 开始检测权限使用
//        [PermissionCheck start];
        
        // 替换bundleID
//        bgl_exchangeMethod([NSBundle class], @selector(bundleIdentifier), [IPAPatchEntry class], @selector(hisBundleID), @selector(bundleIdentifier));
//        bgl_exchangeMethod([NSBundle class], @selector(infoDictionary), [IPAPatchEntry class], @selector(hisInfoDictionary), @selector(infoDictionary));
    });
}

- (NSString *)hisBundleID {
    NSArray * a = [NSThread callStackSymbols];
    NSArray<NSString *> * ar = [[NSString stringWithUTF8String:_dyld_get_image_name(0)] componentsSeparatedByString:@"/"];
    if (![a[1] containsString:ar.lastObject]) {
        return [self hisBundleID];
    }
    return BUNDLEID;
}

- (NSDictionary<NSString *, id> *)hisInfoDictionary {
    NSArray * a = [NSThread callStackSymbols];
    NSArray<NSString *> * ar = [[NSString stringWithUTF8String:_dyld_get_image_name(0)] componentsSeparatedByString:@"/"];
    if (![a[1] containsString:ar.lastObject]) {
        return [self hisInfoDictionary];
    }
    NSMutableDictionary * d = [[NSMutableDictionary alloc] initWithDictionary:[self hisInfoDictionary]];
    d[@"CFBundleIdentifier"] = BUNDLEID;
    NSDictionary<NSString *, id> * infoDictionary = [NSDictionary dictionaryWithDictionary:d];
    return infoDictionary;
}


@end
