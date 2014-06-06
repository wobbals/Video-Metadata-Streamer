//
//  MetadataEncoder.h
//  VideoMetadata
//
//  Created by Charley Robinson on 6/5/14.
//
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface MetadataEncoder : NSObject <OTVideoCapture, OTVideoCaptureConsumer>

-(id)initWithVideoCapture:(id<OTVideoCapture>)videoCapture;


@end
