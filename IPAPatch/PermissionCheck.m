//
//  PermissionCheck.m
//  IPAPatchFramework
//
//  Created by admin on 2021/8/17.
//  Copyright © 2021 Weibo. All rights reserved.
//

#import "PermissionCheck.h"
#import "Tools.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <EventKit/EventKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Contacts/Contacts.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <CoreMotion/CoreMotion.h>
#import <Photos/Photos.h>
#import <Intents/Intents.h>
#import <Speech/Speech.h>
#import <HealthKit/HealthKit.h>
#import <HomeKit/HomeKit.h>
#import <StoreKit/StoreKit.h>
#import <CoreNFC/CoreNFC.h>
#import <AdSupport/AdSupport.h>

@implementation PermissionCheck
+ (void)start {
    NSLog(@"PermissionCheck start");
    bgl_exchangeMethod([CBCentralManager class], @selector(initWithDelegate:queue:options:), [PermissionCheck class], @selector(f_initWithDelegate:queue:options:), @selector(initWithDelegate:queue:options:));
    bgl_exchangeMethod([LAContext class], @selector(canEvaluatePolicy:error:), [PermissionCheck class], @selector(f_canEvaluatePolicy:error:), @selector(canEvaluatePolicy:error:));
    bgl_exchangeMethod([ASIdentifierManager class], @selector(isAdvertisingTrackingEnabled), [PermissionCheck class], @selector(f_isAdvertisingTrackingEnabled), @selector(isAdvertisingTrackingEnabled));
    bgl_exchangeMethod([CLLocationManager class], @selector(init), [PermissionCheck class], @selector(f_CLLocationManager_init), @selector(init));
    bgl_exchangeMethod([CLLocationManager class], @selector(startUpdatingLocation), [PermissionCheck class], @selector(f_startUpdatingLocation), @selector(startUpdatingLocation));
    bgl_exchangeMethod([CMMotionActivityManager class], @selector(init), [PermissionCheck class], @selector(f_CMMotionActivityManager_init), @selector(init));
    bgl_exchangeMethod([HKHealthStore class], @selector(authorizationStatusForType:), [PermissionCheck class], @selector(f_authorizationStatusForType:), @selector(authorizationStatusForType:));
    bgl_exchangeMethod([HMHomeManager class], @selector(init), [PermissionCheck class], @selector(f_HMHomeManager_init), @selector(init));

    exchangeClassMethod(@"EKEventStore", @"authorizationStatusForEntityType:", @"PermissionCheck", @"f_EKEventStore_authorizationStatusForEntityType:");
    exchangeClassMethod(@"AVCaptureDevice", @"authorizationStatusForMediaType:", @"PermissionCheck", @"f_authorizationStatusForMediaType:");
    exchangeClassMethod(@"CNContactStore", @"authorizationStatusForEntityType:", @"PermissionCheck", @"f_CNContactStore_authorizationStatusForEntityType:");
    exchangeClassMethod(@"SKCloudServiceController", @"authorizationStatus", @"PermissionCheck", @"f_SKCloudServiceAuthorizationStatus_authorizationStatus");
    exchangeClassMethod(@"PHPhotoLibrary", @"authorizationStatus", @"PermissionCheck", @"f_PHAuthorizationStatus_authorizationStatus");
    exchangeClassMethod(@"SFSpeechRecognizer", @"authorizationStatus", @"PermissionCheck", @"f_SFSpeechRecognizer_authorizationStatus");

    if (@available(iOS 14.0, *)) {
        exchangeClassMethod(@"PHPhotoLibrary", @"authorizationStatus", @"PermissionCheck", @"f_authorizationStatusForAccessLevel:");
    }
}

- (instancetype)f_HMHomeManager_init {
    NSLog(@"有人在使用HomeKit");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_HMHomeManager_init];
}

- (instancetype)f_CMMotionActivityManager_init {
    NSLog(@"有人在使用健康记录");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_CMMotionActivityManager_init];
}

- (BOOL)f_isAdvertisingTrackingEnabled {
    NSLog(@"有人在使用IDFA");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_isAdvertisingTrackingEnabled];
}

- (instancetype)f_CLLocationManager_init {
    NSLog(@"有人在使用位置信息");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_CLLocationManager_init];
}

- (void)f_startUpdatingLocation {
    NSLog(@"有人在使用位置信息");
    NSLog(@"%@", [NSThread callStackSymbols]);
    [self f_startUpdatingLocation];
}

- (BOOL)f_canEvaluatePolicy:(LAPolicy)policy error:(NSError * __autoreleasing *)error {
    NSLog(@"有人在使用FaceID");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_canEvaluatePolicy:policy error:error];
}

- (instancetype)f_initWithDelegate:(nullable id<CBCentralManagerDelegate>)delegate queue:(nullable dispatch_queue_t)queue options:(nullable NSDictionary<NSString *,id> *)options {
    NSLog(@"有人在使用蓝牙");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_initWithDelegate:delegate queue:queue options:options];
}

- (HKAuthorizationStatus)f_authorizationStatusForType:(HKObjectType *)type; {
    NSLog(@"有人在获取HomeKit权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [self f_authorizationStatusForType:type];
}

+ (CNAuthorizationStatus)f_EKEventStore_authorizationStatusForEntityType:(CNEntityType)entityType {
    if (entityType == EKEntityTypeReminder) {
        NSLog(@"有人在获取备忘录权限");
    } else if (entityType == EKEntityTypeEvent) {
        NSLog(@"有人在获取日历权限");
    }
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_EKEventStore_authorizationStatusForEntityType:entityType];
}

+ (CNAuthorizationStatus)f_CNContactStore_authorizationStatusForEntityType:(CNEntityType)entityType {
    NSLog(@"有人在获取通讯录权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_CNContactStore_authorizationStatusForEntityType:entityType];
}

+ (SKCloudServiceAuthorizationStatus)f_SKCloudServiceAuthorizationStatus_authorizationStatus {
    NSLog(@"有人在获取媒体库权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_SKCloudServiceAuthorizationStatus_authorizationStatus];
}

+ (AVAuthorizationStatus)f_authorizationStatusForMediaType:(AVMediaType)mediaType {
    if (mediaType == AVMediaTypeAudio) {
        NSLog(@"有人在获取麦克风权限");
    } else if (mediaType == AVMediaTypeVideo) {
        NSLog(@"有人在获取相机权限");
    } else {
        NSLog(@"有人在获取媒体权限 %@", mediaType);
    }
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_authorizationStatusForMediaType:mediaType];
}

+ (PHAuthorizationStatus)f_PHAuthorizationStatus_authorizationStatus {
    NSLog(@"有人在获取相册权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_PHAuthorizationStatus_authorizationStatus];
}

+ (PHAuthorizationStatus)f_authorizationStatusForAccessLevel:(PHAccessLevel)accessLevel API_AVAILABLE(ios(14)) {
    NSLog(@"有人在获取相册权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_authorizationStatusForAccessLevel:accessLevel];
}

+ (SFSpeechRecognizerAuthorizationStatus)f_SFSpeechRecognizer_authorizationStatus {
    NSLog(@"有人在获取语音识别权限");
    NSLog(@"%@", [NSThread callStackSymbols]);
    return [PermissionCheck f_SFSpeechRecognizer_authorizationStatus];
}
@end
