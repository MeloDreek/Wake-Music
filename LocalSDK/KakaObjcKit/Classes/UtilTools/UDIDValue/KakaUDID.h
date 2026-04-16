//
//  KakaUDID.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2021/10/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KakaUDID : NSObject

///--------------------------------------------------------------------
/// Usually, the method `+ (NSString *)value` is enough for you to use.
///--------------------------------------------------------------------
/**
 *  method             value, Requires iOS6.0 and later
 *  abstract           Obtain UDID(Unique Device Identity). If it already exits in keychain, return the exit one; otherwise generate a new one and store it into the keychain then return.
 *  discussion         Use 'identifierForVendor + keychain' to make sure UDID consistency even if the App has been removed or reinstalled.
 *  param              NULL
 *  param result       return UDID String
 */
+ (NSString *)value;


/**
 *  method             setDebug:
 *  abstract           Set `YES` to open debug mode, defalut is `NO`.
 *  discussion         Should be called before method `+ (NSString *)value`.
 *  param              mode
 *  param result       void
 */
+ (void)setDebug:(BOOL)mode;


#pragma mark - Extension Method: Insert / Delete / Update / Select
/**
 *  method             selectKeychainItemWithIdentifier: serviceName:
 *  abstract           Find out if the item already exists in the keychain. If exist, return the item, else return nil.
 *  discussion
 *  param              identifier
 *  param              serviceName
 *  param result       return the selected item or nil.
 */
+ (NSData *)selectKeychainItemWithIdentifier:(NSString *)identifier serviceName:(NSString *)serviceName;

/**
 *  method             insertKeychainItemWithValue: identifier: serviceName:
 *  abstract           Insert an item into keychain. If success, return YES, else return NO.
 *  discussion
 *  param              value
 *  param              identifier
 *  param              serviceName
 *  param result       return YES or NO
 */
+ (BOOL)insertKeychainItemWithValue:(NSString *)value identifier:(NSString *)identifier serviceName:(NSString *)serviceName;

/**
 *  method             updateKeychainItemWithValue: identifier: serviceName:
 *  abstract           Update a keychain item, If success, return YES, else return NO.
 *  discussion
 *  param              value
 *  param              identifier
 *  param              serviceName
 *  param result       return YES or NO
 */
+ (BOOL)updateKeychainItemWithValue:(NSString *)value identifier:(NSString *)identifier serviceName:(NSString *)serviceName;

/**
 *  method             deleteKeychainItemWithIdentifier: serviceName:
 *  abstract           Delete a keychain item. If success, return YES, else return NO.
 *  discussion
 *  param              identifier
 *  param              serviceName
 *  param result       return YES or NO
 */
+ (BOOL)deleteKeychainItemWithIdentifier:(NSString *)identifier serviceName:(NSString *)serviceName;

/// 获取CPU核数
+ (int)getCpuCount;

@end

NS_ASSUME_NONNULL_END
