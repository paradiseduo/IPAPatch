//
//  IPAPatchEntry.m
//  IPAPatch
//
//  Created by wutian on 2017/3/17.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import "IPAPatchEntry.h"
#import "Tools.h"

#define BUNDLEID @"xxxxxxx"

@implementation IPAPatchEntry

+ (void)load {
    //使用passHTTPS3时请不要调用显示FLEX，FLEX抓端口的原理跟passHTTPS3的原理一样，因此代码会出现冲突（NSURLProtocol只能存在一个）。
    [Tools showFLEXDelayBy:5];

    //方法交换
//    bgl_exchangeMethod([NSBundle class], @selector(bundleIdentifier), [IPAPatchEntry class], @selector(hisBundleID), @selector(bundleIdentifier));
}

- (NSString *)hisBundleID {
    return BUNDLEID;
}


@end
