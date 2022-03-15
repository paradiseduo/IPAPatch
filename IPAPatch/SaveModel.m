//
//  SaveModel.m
//  IPAPatchFramework
//
//  Created by ParadiseDuo on 2020/8/12.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

#import "SaveModel.h"

static SaveModel * instance = nil;
@interface SaveModel ()
@property (nonatomic, copy) NSMutableArray * save;
@end
@implementation SaveModel

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (instance == nil) {
            instance = [super alloc];
            instance = [instance init];
        }
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (id)copyWithZone:(NSZone *)zone{
    return self;
}

- (NSMutableArray *)getSave {
    return _save;
}

- (void)saveStr:(NSString *)str {
    if (!_save) {
        _save = [[NSMutableArray alloc] init];
    }
    [_save addObject:str];
}

- (void)clean {
    [_save removeAllObjects];
}

@end
