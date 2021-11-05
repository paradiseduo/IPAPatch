//
//  HookURLProtocol.m
//  IPAPatchFramework
//
//  Created by Paradiseduo on 2021/9/6.
//  Copyright © 2021 Weibo. All rights reserved.
//

#import "HookURLProtocol.h"
#import <objc/runtime.h>
#import "zlib.h"

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

@interface HookURLProtocol()<NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession * session;
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
    //打标签，防止无限循环
    NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDataTask * task = [self.session dataTaskWithRequest:[self request]];
    [task resume];
}

- (void)stopLoading
{
    [self.session invalidateAndCancel];
    self.session = nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    //打标签，防止无限循环
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:HookURLProtocolHandledKey inRequest:mutableReqeust];
    permissionCheck(mutableReqeust);
    return [mutableReqeust copy];
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    completionHandler(proposedResponse);
}

#pragma mark - check

void permissionCheck(NSMutableURLRequest *mutableReqeust) {
    NSString * body = @"";
    if ([mutableReqeust.HTTPMethod isEqualToString:@"POST"] && mutableReqeust.HTTPBody == nil && mutableReqeust.HTTPBodyStream != nil) {
        NSInteger maxLength = 1024;
        uint8_t d[maxLength];
        NSInputStream *stream = mutableReqeust.HTTPBodyStream;
        NSMutableData *data = [[NSMutableData alloc] init];
        [stream open];
        BOOL endOfStreamReached = NO;
        while (!endOfStreamReached) {
            NSInteger bytesRead = [stream read:d maxLength:maxLength];
            if (bytesRead == 0) { //文件读取到最后
                endOfStreamReached = YES;
            } else if (bytesRead == -1) { //文件读取错误
                endOfStreamReached = YES;
            } else if (stream.streamError == nil) {
                [data appendBytes:(void *)d length:bytesRead];
            }
        }
        NSData * nd = [data copy];
        [stream close];
        body = bodyString(nd);
    }
    if ([body length] > 0) {
        if (regexCheck(@"^1[3|4|5|7|8][0-9]\\d{8}$", body) || [body.uppercaseString containsString:@"IDFA"]) {
            NSLog(@"🔥 body %@", body);
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

NSString * utf8(NSData * data) {
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

NSString * json(NSData * data) {
    //这里没有先用JSONObjectWithStream去解析JSON，原因在于使用了JSONObjectWithStream之后非json格式的body就转不出来了。不知道为什么。
    id m = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSString * b = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:m options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
    return b;
}

NSData * ungzipData(NSData *compressedData) {
    if ([compressedData length] == 0) {
        return compressedData;
    }
 
    NSUInteger full_length = [compressedData length];
    NSUInteger half_length = [compressedData length] / 2;
 
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
 
    z_stream strm;
    strm.next_in = (Bytef *)[compressedData bytes];
    strm.avail_in = [compressedData length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    if (inflateInit2(&strm, (15+32)) != Z_OK)
        return nil;
 
    while (!done) {
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
    }
 
    if (inflateEnd (&strm) != Z_OK) {
        return nil;
    }
    if (done) {
        [decompressed setLength:strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    return nil;
}

NSString * bodyString(NSData * nd) {
    if (nd) {
        NSString * b = json(nd);
        if ([b length] > 0) {
            return b;
        } else {
            NSString * bb = utf8(nd);
            if ([bb length] > 0) {
                return bb;
            } else {
                NSData * gzip = ungzipData(nd);
                NSString * bbb = json(gzip);
                if ([bbb length] > 0) {
                    return bbb;
                } else {
                    return utf8(gzip);
                }
            }
        }
    }
    return @"";
}

@end
