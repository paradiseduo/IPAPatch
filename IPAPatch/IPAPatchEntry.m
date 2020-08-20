//
//  IPAPatchEntry.m
//  IPAPatch
//
//  Created by wutian on 2017/3/17.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import "IPAPatchEntry.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import "CustomURLProtocol.h"
#import "Tools.h"

#define BUNDLEID @"xxxxxxx"

@class AFSecurityPolicy;

@implementation IPAPatchEntry

+ (void)load
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //使用passHTTPS3时请注释掉下面5行代码，FLEX抓端口的原理跟passHTTPS3的原理一样，因此代码会出现冲突（NSURLProtocol只能存在一个）。
        Class a = NSClassFromString(@"FLEXManager");
        SEL sel1 = NSSelectorFromString(@"sharedManager");
        id obj = [a performSelector:sel1 withObject:nil];
        SEL sel2 = NSSelectorFromString(@"showExplorer");
        [obj performSelector:sel2 withObject:nil];
        
//        bgl_exchangeMethod([NSBundle class], @selector(bundleIdentifier), [IPAPatchEntry class], @selector(hisBundleID), @selector(bundleIdentifier));
    });
//    [self exchangeNSString];
//    bgl_exchangeMethod([NSString class], @selector(stringByAppendingString:), [IPAPatchEntry class], @selector(myStringByAppendingString:),  @selector(stringByAppendingString:));
//    bgl_exchangeMethod([NSMutableString class], @selector(appendString:), [IPAPatchEntry class], @selector(myMutableStringAppendString:), @selector(appendString:));
    [self passHTTPS1];
}

- (NSString *)hisBundleID {
    return BUNDLEID;
}

+ (void)passHTTPS1 {
    /**
            方案1，如果该方案不好使，那么请使用方案2
         */
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), @selector(setSSLPinningMode:), [IPAPatchEntry class], @selector(sslPinningMode:), @selector(setSSLPinningMode:));
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), @selector(setAllowInvalidCertificates:), [IPAPatchEntry class], @selector(allowInvalid:), @selector(setAllowInvalidCertificates:));
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), @selector(setValidatesDomainName:), [IPAPatchEntry class], @selector(validatesDomainName:), @selector(setValidatesDomainName:));
}

+ (void)passHTTPS2 {
    /**
        方案2，如果该方案不好使，那么请使用方案1
     */
    bgl_exchangeMethod(NSClassFromString(@"AFHTTPSessionManager"), @selector(setSecurityPolicy:), [IPAPatchEntry class], @selector(securityPolicy:), @selector(setSecurityPolicy:));
}

+ (void)passHTTPS3 {
    /**
       方案3，如果该方案1/2不好使，那么请使用方案3
    */
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [NSURLProtocol registerClass:[CustomURLProtocol class]];
    }];
}

- (void)securityPolicy:(id)policy {
    Class a = NSClassFromString(@"AFSecurityPolicy");
    SEL sel1 = NSSelectorFromString(@"defaultPolicy");
    id securityPolicy = [a performSelector:sel1];
    SEL sel2 = NSSelectorFromString(@"setAllowInvalidCertificates:");
    [securityPolicy performSelector:sel2 withObject:[NSNumber numberWithBool:YES]];
    SEL sel3 = NSSelectorFromString(@"setValidatesDomainName:");
    [securityPolicy performSelector:sel3 withObject:[NSNumber numberWithBool:NO]];
    
    [self securityPolicy:securityPolicy];
}

- (void)allowInvalid:(BOOL)v {
    [self allowInvalid:YES];
}

- (void)validatesDomainName:(BOOL)y {
    [self validatesDomainName:NO];
}

- (void)sslPinningMode:(NSUInteger)mode {
    [self sslPinningMode:0];
}


+ (void)exchangeNSString {
    SEL sel1 = @selector(stringWithFormat:);
    Method a = class_getClassMethod([NSString class], sel1);

    SEL sel2 = @selector(myStringWithFormat:);
    Method b = class_getClassMethod([IPAPatchEntry class], sel2);

    method_exchangeImplementations(a, b);
}

+ (NSString *)myStringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    va_list ap;
    va_start(ap, format);
    NSMutableString * result = [[NSMutableString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return result;
}

- (NSString *)myStringByAppendingString:(NSString *)str {
    NSString * result = [self myStringByAppendingString:str];
    NSLog(@"$$$: %@", result);
    return result;
}

- (NSMutableString *)myMutableStringAppendString:(NSString *)str {
    NSMutableString * result = [[NSMutableString alloc] init];
    result = [self myMutableStringAppendString:str];
    NSLog(@"###: %@", result);
    return result;
}

@end
