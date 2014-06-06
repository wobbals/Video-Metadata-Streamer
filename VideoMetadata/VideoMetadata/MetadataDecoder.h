//
//  MetadataDecoder.h
//  VideoMetadata
//
//  Created by Charley Robinson on 6/5/14.
//
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface MetadataDecoder : NSObject <OTVideoRender>

- (id)initWithVideoRender:(id<OTVideoRender>)render;

@end
