//
//  HookURLProtocol.m
//  IPAPatchFramework
//
//  Created by Paradiseduo on 2021/9/6.
//  Copyright © 2021 Weibo. All rights reserved.
//

#import "HookURLProtocol.h"
#import "Tools.h"
#import <objc/runtime.h>
#import "zlib.h"

@interface HookURLProtocol()

@end

@implementation HookURLProtocol
+ (void)load {
    bgl_exchangeMethod([NSURLSessionTask class], @selector(resume), [HookURLProtocol class], @selector(f_resume), @selector(resume));
}

- (void)f_resume {
    NSURLSessionTask * task = (NSURLSessionTask *)self;
    if ([@[@"http", @"https"] containsObject:task.originalRequest.URL.scheme] && task.originalRequest.URL.host != nil) {
        permissionCheck(task.originalRequest);
    }
    [self f_resume];
}

#pragma mark - check

void permissionCheck(NSURLRequest *mutableReqeust) {
    NSString * body = @"";
    if ([mutableReqeust.HTTPMethod isEqualToString:@"POST"]) {
        if (mutableReqeust.HTTPBody) {
            body = bodyString(mutableReqeust.HTTPBody);
        } else if (mutableReqeust.HTTPBodyStream != nil) {
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
        } else {
            body = @"";
        }
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
