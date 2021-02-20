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

/// 显示FLEX界面
/// @param delay 延迟调用秒数，建议5s
+ (void)showFLEXDelayBy:(int64_t)delay;

/// 将16进制的hex字符串转成NSData
/// @param hexString 16进制的hex字符串
+ (NSData *)dataForHexString:(NSString *)hexString;

/// 获取对象的IvarList
/// @param obj 要查看的对象
+ (NSDictionary *)getIvarList:(NSObject *)obj;

/// 获取对象的所有对象方法
/// @param object 要查看的对象
+ (void)getMethods:(NSObject *)object;

/// 获取对象的所有属性和属性内容
/// @param obj 要查看的对象
+ (NSDictionary *)getAllPropertiesAndVaules:(NSObject *)obj;

/// 获取当前显示的viewController类型
+ (UIViewController *)getCurrentViewController;

/// 绕过HTTPS检测
+ (void)passHTTPS1;

/// 绕过HTTPS检测
+ (void)passHTTPS2;

/// 绕过HTTPS检测
+ (void)passHTTPS3;

/// 替换[NSString stringWithFormat:(nonnull NSString *), ...]方法
+ (void)exchangeNSStringWithFormat;

/// 替换- (NSString *)stringByAppendingString:(NSString *)aString方法
+ (void)exchangeStringByAppendingString;

/// 替换- (void)appendString:(NSString *)aString;方法
+ (void)exchangeAppendString;

@end

NS_ASSUME_NONNULL_END
