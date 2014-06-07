//
//  ErrorCorrection.h
//  VideoMetadata
//
//  Created by Charley Robinson on 6/6/14.
//
//

#import <Foundation/Foundation.h>

@interface ForwardErrorCorrection : NSObject

+ (NSData*)encodeTruncationExpansionWithData:(NSData*)data;
+ (NSData*)decodeTruncationExpansionWithData:(NSData*)data;

@end
