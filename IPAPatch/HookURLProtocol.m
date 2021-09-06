//
//  HookURLProtocol.m
//  IPAPatchFramework
//
//  Created by Paradiseduo on 2021/9/6.
//  Copyright © 2021 Weibo. All rights reserved.
//

#import "HookURLProtocol.h"
#import <objc/runtime.h>

#define HookURLProtocolHandledKey @"HookURLProtocolHandledKey"

typedef NSURLSessionConfiguration*(*SessionConfigConstructor)(id,SEL);
static SessionConfigConstructor orig_defaultSessionConfiguration;
static SessionConfigConstructor orig_ephemeralSessionConfiguration;

void forSessionConfiguration(NSURLSessionConfiguration* sessionConfig) {
    // Runtime check to make sure the API is available on this version
    if ([sessionConfig respondsToSelector:@selector(protocolClasses)] && [sessionConfig respondsToSelector:@selector(setProtocolClasses:)]) {
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:sessionConfig.protocolClasses];
        Class protoCls = HookURLProtocol.class;
        if (![urlProtocolClasses containsObject:protoCls]) {
            [urlProtocolClasses insertObject:protoCls atIndex:0];
        } else if ([urlProtocolClasses containsObject:protoCls]) {
            [urlProtocolClasses removeObject:protoCls];
        }
        sessionConfig.protocolClasses = urlProtocolClasses;
    }
}

IMP HTTParadiseReplaceMethod(SEL selector, IMP newImpl, Class affectedClass, BOOL isClassMethod) {
    Method origMethod = isClassMethod ? class_getClassMethod(affectedClass, selector) : class_getInstanceMethod(affectedClass, selector);
    IMP origImpl = method_getImplementation(origMethod);

    if (!class_addMethod(isClassMethod ? object_getClass(affectedClass) : affectedClass, selector, newImpl, method_getTypeEncoding(origMethod))) {
        method_setImplementation(origMethod, newImpl);
    }

    return origImpl;
}


static NSURLSessionConfiguration* HTTParadise_defaultSessionConfiguration(id self, SEL _cmd) {
    NSURLSessionConfiguration* config = orig_defaultSessionConfiguration(self ,_cmd); // call original method
    forSessionConfiguration(config);
    return config;
}

static NSURLSessionConfiguration* HTTParadise_ephemeralSessionConfiguration(id self, SEL _cmd) {
    NSURLSessionConfiguration* config = orig_ephemeralSessionConfiguration(self, _cmd); // call original method
    forSessionConfiguration(config);
    return config;
}

@interface HookURLProtocol()<NSURLSessionDataDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLConnection * connection;
@end

@implementation HookURLProtocol
+ (void)load
{
    orig_defaultSessionConfiguration = (SessionConfigConstructor)HTTParadiseReplaceMethod(@selector(defaultSessionConfiguration), (IMP)HTTParadise_defaultSessionConfiguration, [NSURLSessionConfiguration class], YES);
    orig_ephemeralSessionConfiguration = (SessionConfigConstructor)HTTParadiseReplaceMethod(@selector(ephemeralSessionConfiguration), (IMP)HTTParadise_ephemeralSessionConfiguration, [NSURLSessionConfiguration class], YES);
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    //看看是否已经处理过了，防止无限循环
    if ([NSURLProtocol propertyForKey:HookURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    return YES;
}

- (void)startLoading {
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    
    // 实现自己的检测规则，这里只检测了手机号和IDFA
    permissionCheck(mutableReqeust);
    
    //打标签，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:HookURLProtocolHandledKey inRequest:mutableReqeust];
    
    self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
}

- (void)stopLoading
{
    [self.connection cancel];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

#pragma mark - check

void permissionCheck(NSMutableURLRequest *mutableReqeust) {
    NSData * body = mutableReqeust.HTTPBody;
    if (body) {
        NSString * json = [NSString stringWithFormat:@"%@", [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingMutableContainers error:nil]];
        if (regexCheck(@"^1[3|4|5|7|8][0-9]\\d{8}$", json) || [json.uppercaseString containsString:@"IDFA"]) {
            NSLog(@"🔥 json %@", json);
        }
    }
    
    NSString * query = mutableReqeust.URL.query;
    if (query != nil && ![query isEqualToString:@""]) {
        if (regexCheck(@"^1[3|4|5|7|8][0-9]\\d{8}$", query) || [query.uppercaseString containsString:@"IDFA"]) {
            NSLog(@"🔥 query %@", query);
        }
    }
    
    NSString * header = [NSString stringWithFormat:@"%@", mutableReqeust.allHTTPHeaderFields];
    if (regexCheck(@"^1[3|4|5|7|8][0-9]\\d{8}$", header) || [header.uppercaseString containsString:@"IDFA"]) {
        NSLog(@"🔥 header %@", header);
    }
}

bool regexCheck(NSString *pattern ,NSString * str) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];

    NSArray<NSTextCheckingResult *> *result = [regex matchesInString:str options:0 range:NSMakeRange(0, str.length)];
    if (result.count > 0) {
        return true;
    }
    return false;
}

@end
