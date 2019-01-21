//
//  IPAPatchEntry.m
//  IPAPatch
//
//  Created by wutian on 2017/3/17.
//  Copyright © 2017年 Weibo. All rights reserved.
//

#import "IPAPatchEntry.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <mach-o/dyld.h>

@class HXURLExtendsParameters;

@implementation IPAPatchEntry

void checkDylibs(void)
{
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0 ; i < count; ++i) {
        NSString *name = [[NSString alloc]initWithUTF8String:_dyld_get_image_name(i)];
        NSLog(@"%@", name);
    }
}

+ (void)load
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class a = NSClassFromString(@"FLEXManager");
        SEL sel1 = NSSelectorFromString(@"sharedManager");
        id obj = [a performSelector:sel1 withObject:nil];
        SEL sel2 = NSSelectorFromString(@"showExplorer");
        [obj performSelector:sel2 withObject:nil];
    });
    [self exchangeNSString];
//    bgl_exchangeMethod([NSString class], @selector(stringByAppendingString:), [IPAPatchEntry class], @selector(myStringByAppendingString:),  @selector(stringByAppendingString:));
}

+ (void)exchangeNSString {
    SEL sel1 = @selector(stringWithFormat:);
    Method a = class_getClassMethod([NSString class], sel1);

    SEL sel2 = @selector(myStringWithFormat:);
    Method b = class_getClassMethod([IPAPatchEntry class], sel2);

    method_exchangeImplementations(a, b);
}

+ (NSString *)myStringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    va_list ap;
    va_start(ap, format);
    NSMutableString * result = [[NSMutableString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return result;
}

- (NSString *)myStringByAppendingString:(NSString *)str {
    NSString * result = [self myStringByAppendingString:str];
    NSLog(@"myStringByAppendingString: %@", result);
    return result;
}



+ (void)for_example_showAlert
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"Hacked" message:@"Hacked with IPAPatch" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:NULL]];
        UIViewController * controller = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (controller.presentedViewController) {
            controller = controller.presentedViewController;
        }
        [controller presentViewController:alertController animated:YES completion:NULL];
    });
}

/**
 替换任意方法(包括代理方法)
 
 @param originalClass 原先的类
 @param originalSel 原先的方法
 @param replacedClass 新的类(这是最强大的地方:可以是任意的类，不需要是原先类的category或者子类)
 @param replacedSel 新的方法
 @param orginReplaceSel 如果实现了代理方法，那么这里要填上代理方法，如果没实现，这里填originalSel
 */
static void bgl_exchangeMethod(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL orginReplaceSel){
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
        NSLog(@"%s  %s", memberAddress, memberType);
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
+ (NSDictionary *)getAllPropertiesAndVaules:(NSObject *)obj
{
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
    return propsDic;
}



static NSString *base64_encode_data(NSData *data){
    data = [data base64EncodedDataWithOptions:0];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return ret;
}

static NSData *base64_decode(NSString *str){
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return data;
}

#pragma mark - 使用'.der'公钥文件加密

//加密
+ (NSString *)encryptString:(NSString *)str publicKeyWithContentsOfFile:(NSString *)path{
    if (!str || !path)  return nil;
    return [self encryptString:str publicKeyRef:[self getPublicKeyRefWithContentsOfFile:path]];
}

//获取公钥
+ (SecKeyRef)getPublicKeyRefWithContentsOfFile:(NSString *)filePath{
    NSData *certData = [NSData dataWithContentsOfFile:filePath];
    if (!certData) {
        return nil;
    }
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, (CFDataRef)certData);
    SecKeyRef key = NULL;
    SecTrustRef trust = NULL;
    SecPolicyRef policy = NULL;
    if (cert != NULL) {
        policy = SecPolicyCreateBasicX509();
        if (policy) {
            if (SecTrustCreateWithCertificates((CFTypeRef)cert, policy, &trust) == noErr) {
                SecTrustResultType result;
                if (SecTrustEvaluate(trust, &result) == noErr) {
                    key = SecTrustCopyPublicKey(trust);
                }
            }
        }
    }
    if (policy) CFRelease(policy);
    if (trust) CFRelease(trust);
    if (cert) CFRelease(cert);
    return key;
}

+ (NSString *)encryptString:(NSString *)str publicKeyRef:(SecKeyRef)publicKeyRef{
    if(![str dataUsingEncoding:NSUTF8StringEncoding]){
        return nil;
    }
    if(!publicKeyRef){
        return nil;
    }
    NSData *data = [self encryptData:[str dataUsingEncoding:NSUTF8StringEncoding] withKeyRef:publicKeyRef];
    NSString *ret = base64_encode_data(data);
    return ret;
}

#pragma mark - 使用'.der'公钥文件解密
//解密
+ (NSString *)decryptString:(NSString *)str publicKeyWithContentsOfFile:(NSString *)path{
    if (!str || !path)  return nil;
    return [self decryptString:str privateKeyRef:[self getPublicKeyRefWithContentsOfFile:path]];
}

#pragma mark - 使用'.12'私钥文件解密

//解密
+ (NSString *)decryptString:(NSString *)str privateKeyWithContentsOfFile:(NSString *)path password:(NSString *)password{
    if (!str || !path) return nil;
    if (!password) password = @"";
    return [self decryptString:str privateKeyRef:[self getPrivateKeyRefWithContentsOfFile:path password:password]];
}

#pragma mark - 使用'.12'私钥文件加密

//加密
+ (NSString *)encryptString:(NSString *)str privateKeyWithContentsOfFile:(NSString *)path password:(NSString *)password{
    if (!str || !path) return nil;
    if (!password) password = @"";
    return [self encryptString:str publicKeyRef:[self getPrivateKeyRefWithContentsOfFile:path password:password]];
}

//获取私钥
+ (SecKeyRef)getPrivateKeyRefWithContentsOfFile:(NSString *)filePath password:(NSString*)password{
    
    NSData *p12Data = [NSData dataWithContentsOfFile:filePath];
    if (!p12Data) {
        return nil;
    }
    SecKeyRef privateKeyRef = NULL;
    NSMutableDictionary * options = [[NSMutableDictionary alloc] init];
    [options setObject: password forKey:(__bridge id)kSecImportExportPassphrase];
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus securityError = SecPKCS12Import((__bridge CFDataRef) p12Data, (__bridge CFDictionaryRef)options, &items);
    if (securityError == noErr && CFArrayGetCount(items) > 0) {
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
        SecIdentityRef identityApp = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
        securityError = SecIdentityCopyPrivateKey(identityApp, &privateKeyRef);
        if (securityError != noErr) {
            privateKeyRef = NULL;
        }
    }
    CFRelease(items);
    
    return privateKeyRef;
}

+ (NSString *)decryptString:(NSString *)str privateKeyRef:(SecKeyRef)privKeyRef{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!privKeyRef) {
        return nil;
    }
    data = [self decryptData:data withKeyRef:privKeyRef];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return ret;
}

#pragma mark - 使用公钥字符串加密

/* START: Encryption with RSA public key */

//使用公钥字符串加密
+ (NSString *)encryptString:(NSString *)str publicKey:(NSString *)pubKey{
    NSData *data = [self encryptData:[str dataUsingEncoding:NSUTF8StringEncoding] publicKey:pubKey];
    NSString *ret = base64_encode_data(data);
    return ret;
}

+ (NSData *)encryptData:(NSData *)data publicKey:(NSString *)pubKey{
    if(!data || !pubKey){
        return nil;
    }
    SecKeyRef keyRef = [self addPublicKey:pubKey];
    if(!keyRef){
        return nil;
    }
    return [self encryptData:data withKeyRef:keyRef];
}

+ (SecKeyRef)addPublicKey:(NSString *)key{
    NSRange spos = [key rangeOfString:@"-----BEGIN PUBLIC KEY-----"];
    NSRange epos = [key rangeOfString:@"-----END PUBLIC KEY-----"];
    if(spos.location != NSNotFound && epos.location != NSNotFound){
        NSUInteger s = spos.location + spos.length;
        NSUInteger e = epos.location;
        NSRange range = NSMakeRange(s, e-s);
        key = [key substringWithRange:range];
    }
    key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
    
    // This will be base64 encoded, decode it.
    NSData *data = base64_decode(key);
    data = [self stripPublicKeyHeader:data];
    if(!data){
        return nil;
    }
    
    //a tag to read/write keychain storage
    NSString *tag = @"RSAUtil_PubKey";
    NSData *d_tag = [NSData dataWithBytes:[tag UTF8String] length:[tag length]];
    
    // Delete any old lingering key with the same tag
    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
    SecItemDelete((__bridge CFDictionaryRef)publicKey);
    
    // Add persistent version of the key to system keychain
    [publicKey setObject:data forKey:(__bridge id)kSecValueData];
    [publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)
     kSecAttrKeyClass];
    [publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)
     kSecReturnPersistentRef];
    
    CFTypeRef persistKey = nil;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)publicKey, &persistKey);
    if (persistKey != nil){
        CFRelease(persistKey);
    }
    if ((status != noErr) && (status != errSecDuplicateItem)) {
        return nil;
    }
    
    [publicKey removeObjectForKey:(__bridge id)kSecValueData];
    [publicKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
    [publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    // Now fetch the SecKeyRef version of the key
    SecKeyRef keyRef = nil;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&keyRef);
    if(status != noErr){
        return nil;
    }
    return keyRef;
}

+ (NSData *)stripPublicKeyHeader:(NSData *)d_key{
    // Skip ASN.1 public key header
    if (d_key == nil) return(nil);
    
    unsigned long len = [d_key length];
    if (!len) return(nil);
    
    unsigned char *c_key = (unsigned char *)[d_key bytes];
    unsigned int  idx     = 0;
    
    if (c_key[idx++] != 0x30) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    // PKCS #1 rsaEncryption szOID_RSA_RSA
    static unsigned char seqiod[] =
    { 0x30,   0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
        0x01, 0x05, 0x00 };
    if (memcmp(&c_key[idx], seqiod, 15)) return(nil);
    
    idx += 15;
    
    if (c_key[idx++] != 0x03) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    if (c_key[idx++] != '\0') return(nil);
    
    // Now make a new NSData from this buffer
    return ([NSData dataWithBytes:&c_key[idx] length:len - idx]);
}

+ (NSData *)encryptData:(NSData *)data withKeyRef:(SecKeyRef) keyRef{
    const uint8_t *srcbuf = (const uint8_t *)[data bytes];
    size_t srclen = (size_t)data.length;
    
    size_t block_size = SecKeyGetBlockSize(keyRef) * sizeof(uint8_t);
    void *outbuf = malloc(block_size);
    size_t src_block_size = block_size - 11;
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    for(int idx=0; idx<srclen; idx+=src_block_size){
        //NSLog(@"%d/%d block_size: %d", idx, (int)srclen, (int)block_size);
        size_t data_len = srclen - idx;
        if(data_len > src_block_size){
            data_len = src_block_size;
        }
        
        size_t outlen = block_size;
        OSStatus status = noErr;
        status = SecKeyEncrypt(keyRef,
                               kSecPaddingPKCS1,
                               srcbuf + idx,
                               data_len,
                               outbuf,
                               &outlen
                               );
        if (status != 0) {
            NSLog(@"SecKeyEncrypt fail. Error Code: %d", status);
            ret = nil;
            break;
        }else{
            [ret appendBytes:outbuf length:outlen];
        }
    }
    
    free(outbuf);
    CFRelease(keyRef);
    return ret;
}

/* END: Encryption with RSA public key */

#pragma mark - 使用私钥字符串解密

/* START: Decryption with RSA private key */

//使用私钥字符串解密
+ (NSString *)decryptString:(NSString *)str privateKey:(NSString *)privKey{
    if (!str) return nil;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    data = [self decryptData:data privateKey:privKey];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return ret;
}

+ (NSData *)decryptData:(NSData *)data privateKey:(NSString *)privKey{
    if(!data || !privKey){
        return nil;
    }
    SecKeyRef keyRef = [self addPrivateKey:privKey];
    if(!keyRef){
        return nil;
    }
    return [self decryptData:data withKeyRef:keyRef];
}

+ (SecKeyRef)addPrivateKey:(NSString *)key{
    NSRange spos = [key rangeOfString:@"-----BEGIN RSA PRIVATE KEY-----"];
    NSRange epos = [key rangeOfString:@"-----END RSA PRIVATE KEY-----"];
    if(spos.location != NSNotFound && epos.location != NSNotFound){
        NSUInteger s = spos.location + spos.length;
        NSUInteger e = epos.location;
        NSRange range = NSMakeRange(s, e-s);
        key = [key substringWithRange:range];
    }
    key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
    
    // This will be base64 encoded, decode it.
    NSData *data = base64_decode(key);
    data = [self stripPrivateKeyHeader:data];
    if(!data){
        return nil;
    }
    
    //a tag to read/write keychain storage
    NSString *tag = @"RSAUtil_PrivKey";
    NSData *d_tag = [NSData dataWithBytes:[tag UTF8String] length:[tag length]];
    
    // Delete any old lingering key with the same tag
    NSMutableDictionary *privateKey = [[NSMutableDictionary alloc] init];
    [privateKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [privateKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [privateKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
    SecItemDelete((__bridge CFDictionaryRef)privateKey);
    
    // Add persistent version of the key to system keychain
    [privateKey setObject:data forKey:(__bridge id)kSecValueData];
    [privateKey setObject:(__bridge id) kSecAttrKeyClassPrivate forKey:(__bridge id)
     kSecAttrKeyClass];
    [privateKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)
     kSecReturnPersistentRef];
    
    CFTypeRef persistKey = nil;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)privateKey, &persistKey);
    if (persistKey != nil){
        CFRelease(persistKey);
    }
    if ((status != noErr) && (status != errSecDuplicateItem)) {
        return nil;
    }
    
    [privateKey removeObjectForKey:(__bridge id)kSecValueData];
    [privateKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
    [privateKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
    [privateKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    // Now fetch the SecKeyRef version of the key
    SecKeyRef keyRef = nil;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)privateKey, (CFTypeRef *)&keyRef);
    if(status != noErr){
        return nil;
    }
    return keyRef;
}

+ (NSData *)stripPrivateKeyHeader:(NSData *)d_key{
    // Skip ASN.1 private key header
    if (d_key == nil) return(nil);
    
    unsigned long len = [d_key length];
    if (!len) return(nil);
    
    unsigned char *c_key = (unsigned char *)[d_key bytes];
    unsigned int  idx     = 22; //magic byte at offset 22
    
    if (0x04 != c_key[idx++]) return nil;
    
    //calculate length of the key
    unsigned int c_len = c_key[idx++];
    int det = c_len & 0x80;
    if (!det) {
        c_len = c_len & 0x7f;
    } else {
        int byteCount = c_len & 0x7f;
        if (byteCount + idx > len) {
            //rsa length field longer than buffer
            return nil;
        }
        unsigned int accum = 0;
        unsigned char *ptr = &c_key[idx];
        idx += byteCount;
        while (byteCount) {
            accum = (accum << 8) + *ptr;
            ptr++;
            byteCount--;
        }
        c_len = accum;
    }
    
    // Now make a new NSData from this buffer
    return [d_key subdataWithRange:NSMakeRange(idx, c_len)];
}

+ (NSData *)decryptData:(NSData *)data withKeyRef:(SecKeyRef) keyRef{
    const uint8_t *srcbuf = (const uint8_t *)[data bytes];
    size_t srclen = (size_t)data.length;
    
    size_t block_size = SecKeyGetBlockSize(keyRef) * sizeof(uint8_t);
    UInt8 *outbuf = malloc(block_size);
    size_t src_block_size = block_size;
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    for(int idx=0; idx<srclen; idx+=src_block_size){
        //NSLog(@"%d/%d block_size: %d", idx, (int)srclen, (int)block_size);
        size_t data_len = srclen - idx;
        if(data_len > src_block_size){
            data_len = src_block_size;
        }
        
        size_t outlen = block_size;
        OSStatus status = noErr;
        status = SecKeyDecrypt(keyRef,
                               kSecPaddingNone,
                               srcbuf + idx,
                               data_len,
                               outbuf,
                               &outlen
                               );
        if (status != 0) {
            NSLog(@"SecKeyEncrypt fail. Error Code: %d", status);
            ret = nil;
            break;
        }else{
            //the actual decrypted data is in the middle, locate it!
            int idxFirstZero = -1;
            int idxNextZero = (int)outlen;
            for ( int i = 0; i < outlen; i++ ) {
                if ( outbuf[i] == 0 ) {
                    if ( idxFirstZero < 0 ) {
                        idxFirstZero = i;
                    } else {
                        idxNextZero = i;
                        break;
                    }
                }
            }
            
            [ret appendBytes:&outbuf[idxFirstZero+1] length:idxNextZero-idxFirstZero-1];
        }
    }
    
    free(outbuf);
    CFRelease(keyRef);
    return ret;
}

@end
