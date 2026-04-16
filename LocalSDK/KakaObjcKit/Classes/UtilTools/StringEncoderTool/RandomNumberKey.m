//
//  KakatringResultKey.m
//  KakaObjcKit
//
//  Created by Kaka Inc.on 2022/5/4.
//

#import "RandomNumberKey.h"

#pragma mark - 结果集合

const char *Random_CString(const EncryptStringData *data)
{
    if (data->decoded == 1) return data->value;
    for (int i = 0; i < data->length; i++) {
        data->value[i] ^= data->factor;
    }
    ((EncryptStringData *)data)->decoded = 1;
    return data->value;
}

NSString *Random_OCString(const EncryptStringData *data)
{
    return [NSString stringWithUTF8String:Random_CString(data)];
}















#pragma mark - 结果集合
/* 不可变的Data */
const EncryptStringData * const _153337243 = &(EncryptStringData){
    .factor = (char)116,
    .value = (char []){31,33,7,17,6,39,13,25,25,17,0,6,29,23,63,17,13,0},
    .length = 17
};

/* 不可变的Data */
const EncryptStringData * const _2262129051 = &(EncryptStringData){
    .factor = (char)5,
    .value = (char []){86,112,103,118,108,97,124,51,90,68,118,118,100,118,118,108,107,100,113,108,106,107,48,90,70,96,119,113,108,99,124,55,90,86,113,119,108,115,96,54,90,70,106,104,103,108,107,96,52,90,81,119,100,107,118,102,96,107,97,53,90,68,97,111,106,108,107,51,90,70,106,107,118,113,108,113,112,96,107,113,0},
    .length = 80
};


/* kUserInfoKey */
const EncryptStringData * const _365239537 = &(EncryptStringData){
    .factor = (char)59,
    .value = (char []){80,110,72,94,73,114,85,93,84,112,94,66,0},
    .length = 12
};

/* Qlse0AVYc0V7ywq/D/1TlGBjmi2MPLBctV+FF1ozoWw= */
const EncryptStringData * const _2021160683 = &(EncryptStringData){
    .factor = (char)105,
    .value = (char []){56,5,26,12,89,40,63,48,10,89,63,94,16,30,24,70,45,70,88,61,5,46,43,3,4,0,91,36,57,37,43,10,29,63,66,47,47,88,6,19,6,62,30,84,0},
    .length = 44
};

/* https://www.i4.cn/pro_pc.html */
const EncryptStringData * const _1280363605 = &(EncryptStringData){
    .factor = (char)-92,
    .value = (char []){-52,-48,-48,-44,-41,-98,-117,-117,-45,-45,-45,-118,-51,-112,-118,-57,-54,-117,-44,-42,-53,-5,-44,-57,-118,-52,-48,-55,-56,0},
    .length = 29
};
