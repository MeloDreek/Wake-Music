//
//  KakatringResultKey.h
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import <Foundation/Foundation.h>

#ifndef RandomNumberKey_h
#define RandomNumberKey_h

typedef struct {
    char factor;
    char *value;
    int length;
    char decoded;
} EncryptStringData;

const char *Random_CString(const EncryptStringData *data);

#ifdef __OBJC__
#import <Foundation/Foundation.h>
NSString *Random_OCString(const EncryptStringData *data);
#endif

#endif


#pragma mark - 结果集合
/* 永不可变的Data */
extern const EncryptStringData * const _153337243;

/* 永不可变的Data */
extern const EncryptStringData * const _2262129051;

/* kUserInfoKey */
extern const EncryptStringData * const _365239537;

/* Qlse0AVYc0V7ywq/D/1TlGBjmi2MPLBctV+FF1ozoWw= */
extern const EncryptStringData * const _2021160683;

/* https://www.i4.cn/pro_pc.html */
extern const EncryptStringData * const _1280363605;


