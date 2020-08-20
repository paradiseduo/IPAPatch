//
//  Tools.h
//  IPAPatchFramework
//
//  Created by ParadiseDuo on 2020/8/12.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

NS_ASSUME_NONNULL_BEGIN

void checkDylibs(void);

/**
 替换任意方法(包括代理方法)
 
 @param originalClass 原先的类
 @param originalSel 原先的方法
 @param replacedClass 新的类(这是最强大的地方:可以是任意的类，不需要是原先类的category或者子类)
 @param replacedSel 新的方法
 @param orginReplaceSel 如果实现了代理方法，那么这里要填上代理方法，如果没实现，这里填originalSel
 */
void bgl_exchangeMethod(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL orginReplaceSel);

/// 替换类方法
/// @param cls1 主类
/// @param name1 主类方法
/// @param cls2 伪类
/// @param name2 伪类方法
void exchangeClassMethod(NSString * _Nullable cls1, NSString * _Nonnull name1, NSString * _Nullable cls2, NSString * _Nonnull name2);

@interface Tools : NSObject
+ (NSData *)dataForHexString:(NSString *)hexString;
+ (NSDictionary *)getIvarList:(NSObject *)obj;
+ (void)getMethods:(NSObject *)object;
/* 获取对象的所有属性和属性内容 */
+ (NSDictionary *)getAllPropertiesAndVaules:(NSObject *)obj;
+ (UIViewController *)getCurrentViewController;
@end

NS_ASSUME_NONNULL_END
