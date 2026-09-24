//
//  TagLibHeader.h
//  KakaTaglibKit
//
//  Created by 张文 on 12/22/24.
//

#ifndef TagLibHeader_h
#define TagLibHeader_h

#import <Foundation/Foundation.h>

// Logger.h
#ifdef DEBUG
#define DebugLog(s, ...) NSLog(s, ##__VA_ARGS__)
#else
#define DebugLog(s, ...)
#endif


#endif /* TagLibHeader_h */
