//
//  SaveModel.h
//  IPAPatchFramework
//
//  Created by ParadiseDuo on 2020/8/12.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SaveModel : NSObject
+ (instancetype)shared;

- (NSMutableArray *)getSave;

- (void)saveStr:(NSString *)str;

- (void)clean;
@end

NS_ASSUME_NONNULL_END
