//
//  IPAPatchEntry.h
//  IPAPatch
//
//  Created by wutian on 2017/3/17.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPAPatchEntry : NSObject

@end

@interface SaveModel : NSObject
+ (instancetype)shared;

- (NSMutableArray *)getSave;

- (void)saveStr:(NSString *)str;

- (void)clean;
@end
