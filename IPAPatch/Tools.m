//
//  Tools.m
//  IPAPatchFramework
//
//  Created by ParadiseDuo on 2020/8/12.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

#import "Tools.h"
#import "CustomURLProtocol.h"


void checkDylibs(void)
{
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0 ; i < count; ++i) {
        NSString *name = [[NSString alloc]initWithUTF8String:_dyld_get_image_name(i)];
        NSLog(@"%@", name);
    }
}


/// 替换类方法
/// @param cls1 主类
/// @param name1 主类方法
/// @param cls2 伪类
/// @param name2 伪类方法
void exchangeClassMethod(NSString * _Nullable cls1, NSString * _Nonnull name1, NSString * _Nullable cls2, NSString * _Nonnull name2) {
    method_exchangeImplementations(class_getClassMethod(NSClassFromString(cls1), NSSelectorFromString(name1)), class_getClassMethod(NSClassFromString(cls2), NSSelectorFromString(name2)));
}

/**
 替换任意方法(包括代理方法)
 
 @param originalClass 原先的类
 @param originalSel 原先的方法
 @param replacedClass 新的类(这是最强大的地方:可以是任意的类，不需要是原先类的category或者子类)
 @param replacedSel 新的方法
 @param orginReplaceSel 如果实现了代理方法，那么这里要填上代理方法，如果没实现，这里填originalSel
 */
void bgl_exchangeMethod(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL orginReplaceSel){
    // 原方法
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    // 如果没有实现 delegate 方法，则手动动态添加
    if (!originalMethod) {
        Method orginReplaceMethod = class_getInstanceMethod(replacedClass, orginReplaceSel);
        BOOL didAddOriginMethod = class_addMethod(originalClass, originalSel, method_getImplementation(orginReplaceMethod), method_getTypeEncoding(orginReplaceMethod));
        if (didAddOriginMethod) {
            NSLog(@"did Add Origin Replace Method");
        }
        return;
    }
    // 向实现 delegate 的类中添加新的方法
    // 这里是向 originalClass 的 replaceSel（@selector(replace_webViewDidFinishLoad:)） 添加 replaceMethod
    BOOL didAddMethod = class_addMethod(originalClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (didAddMethod) {
        // 添加成功
        NSLog(@"class_addMethod_success --> (%@)", NSStringFromSelector(replacedSel));
        // 重新拿到添加被添加的 method,这里是关键(注意这里 originalClass, 不 replacedClass), 因为替换的方法已经添加到原类中了, 应该交换原类中的两个方法
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        // 实现交换
        method_exchangeImplementations(originalMethod, newMethod);
    }else{
        // 添加失败，则说明已经 hook 过该类的 delegate 方法，防止多次交换。
        NSLog(@"Already hook class --> (%@)",NSStringFromClass(originalClass));
    }
}

@implementation Tools
+ (void)showFLEXDelayBy:(int64_t)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class a = NSClassFromString(@"FLEXManager");
        SEL sel1 = NSSelectorFromString(@"sharedManager");
        id obj = [a performSelector:sel1 withObject:nil];
        SEL sel2 = NSSelectorFromString(@"showExplorer");
        [obj performSelector:sel2 withObject:nil];
    });
}

+ (void)passHTTPS1 {
    /**
        方案1，如果该方案不好使，那么请使用方案2
     */
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), NSSelectorFromString(@"setSSLPinningMode:"), [Tools class], @selector(sslPinningMode:), NSSelectorFromString(@"setSSLPinningMode:"));
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), NSSelectorFromString(@"setAllowInvalidCertificates:"), [Tools class], @selector(allowInvalid:), NSSelectorFromString(@"setAllowInvalidCertificates:"));
    bgl_exchangeMethod(NSClassFromString(@"AFSecurityPolicy"), NSSelectorFromString(@"setValidatesDomainName:"), [Tools class], @selector(validatesDomainName:), NSSelectorFromString(@"setAllowInvalidCertificates:"));
}

- (void)allowInvalid:(BOOL)v {
    [self allowInvalid:YES];
}

- (void)validatesDomainName:(BOOL)y {
    [self validatesDomainName:NO];
}

- (void)sslPinningMode:(NSUInteger)mode {
    [self sslPinningMode:0];
}

+ (void)passHTTPS2 {
    /**
        方案2，如果该方案不好使，那么请使用方案1
     */
    bgl_exchangeMethod(NSClassFromString(@"AFHTTPSessionManager"), NSSelectorFromString(@"setSecurityPolicy:"), [Tools class], @selector(securityPolicy:), NSSelectorFromString(@"setSecurityPolicy:"));
}

- (void)securityPolicy:(id)policy {
    Class a = NSClassFromString(@"AFSecurityPolicy");
    SEL sel1 = NSSelectorFromString(@"defaultPolicy");
    id securityPolicy = [a performSelector:sel1];
    SEL sel2 = NSSelectorFromString(@"setAllowInvalidCertificates:");
    [securityPolicy performSelector:sel2 withObject:[NSNumber numberWithBool:YES]];
    SEL sel3 = NSSelectorFromString(@"setValidatesDomainName:");
    [securityPolicy performSelector:sel3 withObject:[NSNumber numberWithBool:NO]];
    
    [self securityPolicy:securityPolicy];
}

+ (void)passHTTPS3 {
    /**
       方案3，如果该方案1/2不好使，那么请使用方案3
    */
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [NSURLProtocol registerClass:[CustomURLProtocol class]];
    }];
}


+ (void)exchangeNSStringWithFormat {
    exchangeClassMethod(@"NSString", @"stringWithFormat:", @"Tools", @"myStringWithFormat:");
}

+ (NSString *)myStringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    va_list ap;
    va_start(ap, format);
    NSMutableString * result = [[NSMutableString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return result;
}

+ (void)exchangeStringByAppendingString {
    bgl_exchangeMethod([NSString class], NSSelectorFromString(@"stringByAppendingString:"), [Tools class], @selector(myStringByAppendingString:),  NSSelectorFromString(@"stringByAppendingString:"));
}

- (NSString *)myStringByAppendingString:(NSString *)str {
    NSString * result = [self myStringByAppendingString:str];
    NSLog(@"$$$: %@", result);
    return result;
}

+ (void)exchangeAppendString {
    bgl_exchangeMethod([NSMutableString class], NSSelectorFromString(@"appendString:"), [Tools class], @selector(myMutableStringAppendString:), NSSelectorFromString(@"appendString:"));
}

- (NSMutableString *)myMutableStringAppendString:(NSString *)str {
    NSMutableString * result = [[NSMutableString alloc] init];
    result = [self myMutableStringAppendString:str];
    NSLog(@"###: %@", result);
    return result;
}

+ (NSData *)dataForHexString:(NSString *)hexString {
    if (hexString == nil) {
        return nil;
    }
    const char* ch = [[hexString lowercaseString] cStringUsingEncoding:NSUTF8StringEncoding];
    NSMutableData* data = [NSMutableData data];
    while (*ch) {
        if (*ch == ' ') {
            continue;
        }
        char byte = 0;
        if ('0' <= *ch && *ch <= '9') {
            byte = *ch - '0';
        }else if ('a' <= *ch && *ch <= 'f') {
            byte = *ch - 'a' + 10;
        }else if ('A' <= *ch && *ch <= 'F') {
            byte = *ch - 'A' + 10;
        }
        ch++;
        byte = byte << 4;
        if (*ch) {
            if ('0' <= *ch && *ch <= '9') {
                byte += *ch - '0';
            } else if ('a' <= *ch && *ch <= 'f') {
                byte += *ch - 'a' + 10;
            }else if('A' <= *ch && *ch <= 'F'){
                byte += *ch - 'A' + 10;
            }
            ch++;
        }
        [data appendBytes:&byte length:1];
    }
    return data;
}

+ (NSDictionary *)getIvarList:(NSObject *)obj {
    NSMutableDictionary * a = [[NSMutableDictionary alloc] init];
    unsigned  int count = 0;
    Ivar *members = class_copyIvarList([obj class], &count);
    
    for (int i = 0; i < count; i++)
    {
        Ivar var = members[i];
        const char *memberAddress = ivar_getName(var);
        const char *memberType = ivar_getTypeEncoding(var);
        [a setValue:[NSString stringWithUTF8String:memberType] forKey:[NSString stringWithUTF8String:memberAddress]];
        NSLog(@"IvarList: %s  %s", memberAddress, memberType);
    }
    return a;
}

+ (void)getMethods:(NSObject *)object {
    unsigned int count = 0;
    //所有在.m文件显式实现的方法都会被找到
    Method *mets = class_copyMethodList([object class], &count);
    for(int i=0;i<count;i++){
        NSString *str = [NSString stringWithCString:method_getTypeEncoding(mets[i]) encoding:NSUTF8StringEncoding];
        SEL sel = method_getName(mets[i]);
        NSString *name = [NSString stringWithCString:sel_getName(sel) encoding:NSUTF8StringEncoding];
        NSLog(@"方法名：%@\n属性：%@",name,str);
    }
}

/* 获取对象的所有属性和属性内容 */
+ (NSDictionary *)getAllPropertiesAndVaules:(NSObject *)obj {
    NSMutableDictionary *propsDic = [NSMutableDictionary dictionary];
    unsigned int outCount;
    objc_property_t *properties =class_copyPropertyList([obj class], &outCount);
    for ( int i = 0; i<outCount; i++)
    {
        objc_property_t property = properties[i];
        const char* char_f =property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:char_f];
        id propertyValue = [obj valueForKey:(NSString *)propertyName];
        if (propertyValue) {
            [propsDic setObject:propertyValue forKey:propertyName];
        }
    }
    free(properties);
    NSLog(@"AllPropertiesAndVaules: %@", propsDic);
    return propsDic;
}

+ (UIViewController *)getCurrentViewController {
    UIViewController * result = [[UIViewController alloc] init];
    UIWindow * window = [UIApplication sharedApplication].keyWindow;
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray * windows = [UIApplication sharedApplication].windows;
        for (UIWindow * temp in windows) {
            if (temp.windowLevel == UIWindowLevelNormal) {
                window = temp;
                break;
            }
        }
    }
    
    UIViewController * rootVC = window.rootViewController;
    if (rootVC) {
        UIView * frontView = window.subviews.firstObject;
        if (frontView) {
            UIResponder * nextResponder = frontView.nextResponder;
            if (rootVC.presentedViewController) {
                nextResponder = rootVC.presentedViewController;
            }
            if ([nextResponder isKindOfClass:[UITabBarController class]]) {
                UITabBarController * tabbar = (UITabBarController *)nextResponder;
                UINavigationController * nav = (UINavigationController *)tabbar.viewControllers[tabbar.selectedIndex];
                result = nav.childViewControllers.lastObject;
            }else if ([nextResponder isKindOfClass:[UINavigationController class]]) {
                UINavigationController * nav = (UINavigationController *)nextResponder;
                result = nav.childViewControllers.lastObject;
            }else {
                if ([nextResponder isKindOfClass:[UIView class]]) {
                    
                }else {
                    result = (UIViewController *)nextResponder;
                }
            }
        }
    }
    return result;
}
@end
