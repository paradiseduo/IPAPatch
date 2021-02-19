//
//  DobbyOC.h
//  Dobby
//
//  Created by paradiseduo on 2021/2/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DobbyOC : NSObject
+ (NSNumber *)dobbyHookWith:(void *)function_address replace:(void *)replace_call origin:(void *_Nonnull*_Nonnull)origin_call;
@end

NS_ASSUME_NONNULL_END
