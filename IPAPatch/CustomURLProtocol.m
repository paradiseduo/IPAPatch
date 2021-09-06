//
//  CustomURLProtocol.m
//  IPAPatch
//
//  Created by Youssef on 2019/12/20.
//  Copyright © 2019 Weibo. All rights reserved.
//

#import "CustomURLProtocol.h"

#define URLProtocolHandledKey @"URLProtocolHandledKey"

@interface CustomURLProtocol()<NSURLSessionDataDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLConnection * connection;
@end

@implementation CustomURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *scheme = [[request URL] scheme];
    if ( ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame || [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame))
    {
        //看看是否已经处理过了，防止无限循环
        if ([NSURLProtocol propertyForKey:URLProtocolHandledKey inRequest:request]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

- (void)startLoading {
    /* 如果想直接返回缓存的结果，构建一个NSURLResponse对象
    if (cachedResponse) {
        
        NSData *data = cachedResponse.data; //缓存的数据
        NSString *mimeType = cachedResponse.mimeType;
        NSString *encoding = cachedResponse.encoding;
        
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL
                                                            MIMEType:mimeType
                                               expectedContentLength:data.length
                                                    textEncodingName:encoding];
        
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
    */
    
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    
    //打标签，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:URLProtocolHandledKey inRequest:mutableReqeust];
    
    self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
}

- (void)stopLoading
{
    [self.connection cancel];
}

#pragma mark - NSURLConnectionDelegate

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}


+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSString * ori = request.URL.absoluteString;
    
    if ([ori containsString:@"http://"]) {
        return request;
    } else {
        NSString * newURL = [ori stringByReplacingOccurrencesOfString:@"https" withString:@"http"];
        NSURLRequest * req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:newURL]];
        return req;
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    //    NSURLSessionAuthChallengeUseCredential = 0, 使用（信任）证书
    //    NSURLSessionAuthChallengePerformDefaultHandling = 1, 默认，忽略
    //    NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,   取消
    //    NSURLSessionAuthChallengeRejectProtectionSpace = 3,  这次取消，下载次再来问
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential * c = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengeUseCredential, c);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    //    NSURLSessionAuthChallengeUseCredential = 0, 使用（信任）证书
    //    NSURLSessionAuthChallengePerformDefaultHandling = 1, 默认，忽略
    //    NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,   取消
    //    NSURLSessionAuthChallengeRejectProtectionSpace = 3,  这次取消，下载次再来问
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential * c = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengeUseCredential, c);
        }
    }
}
@end
