//
//  MetadataEncoder.m
//  VideoMetadata
//
//  Created by Charley Robinson on 6/5/14.
//
//

#import "MetadataEncoder.h"
#import "MetadataConfig.h"
#import "ForwardErrorCorrection.h"

@implementation MetadataEncoder {
    /** 
     * We are acting as both consumer of media and producer. We'll receive
     * captured video frames from the real video source, embed metadata into
     * part of our mule frame, and copy the legit data from the rest of the
     * frame.
     */
    id<OTVideoCaptureConsumer> _videoCaptureConsumer;
    
    /**
     * The real video capture. We forward commands from OpenTok to this
     * instance.
     */
    id<OTVideoCapture> _videoCapture;
    
    /**
     * The mule frame. Takes copies of legit video frames and adds metadata
     * along with the video.
     */
    OTVideoFrame* _muleFrame;
    uint8_t* _muleFrameData;
    size_t _muleBufferSize;
    uint32_t _muleMetadataPixelCount;
    
    uint16_t _maxBytesOfMetadataPerFrame;
    NSMutableData* _muleData;
    int32_t* randU;
    int32_t* randV;
}

#pragma mark Object Lifecycle

-(id)initWithVideoCapture:(id<OTVideoCapture>)videoCapture {
    self = [super init];
    if (self) {
        // Ordering is important here! OTPublisher will release its default
        // capturer (which we want to keep for self) when we set self
        // as the "official" capturer.
        _videoCapture = [videoCapture retain];
        [_videoCapture setVideoCaptureConsumer:self];
        char someData[] = MULE_MAGIC_NUMBER;
        _muleData = [[NSMutableData alloc] initWithBytes:someData
                                                  length:strlen(someData)];
        char payload[] = "helloworld!";
        uint8_t payloadSize = strlen(payload);
        NSData* mulePayload = [NSData dataWithBytes:payload length:payloadSize];
        mulePayload = [ForwardErrorCorrection encodeTruncationExpansionWithData:mulePayload];
        payloadSize = mulePayload.length;
        
        [_muleData appendBytes:&payloadSize length:sizeof(payloadSize)];
        [_muleData appendData:mulePayload];
        
        randU = (int32_t*)calloc(_muleData.length, sizeof(int32_t));
        randV = (int32_t*)calloc(_muleData.length, sizeof(int32_t));
        for (int i = 0; i < _muleData.length; i++) {
            randU[i] = rand();
            randV[i] = rand();
        }
        
        _maxBytesOfMetadataPerFrame = _muleData.length;
    }
    return self;
}

- (void)dealloc {
    free(_muleFrameData);
    [_muleFrame release];
    [_videoCapture release];
    [_muleData release];
    [super dealloc];
}

#pragma mark - Public API



#pragma mark - Private API

- (void)updateMuleFrameWithRealFrame:(OTVideoFrame*)frame {
    if (frame.format.imageHeight == _muleFrame.format.imageHeight &&
        frame.format.imageWidth == _muleFrame.format.imageWidth)
    {
        return;
    }
    
    size_t bufferSize = 0;
    // first, calculate the real image size
    for (NSNumber* bytesPerRow in frame.format.bytesPerRow) {
        bufferSize += [bytesPerRow intValue] * frame.format.imageHeight;
    }
    // then, add the padding we'll use for mule data
    uint16_t numRowsOfMetadata =
    (_maxBytesOfMetadataPerFrame /
     (frame.format.imageWidth / ASSUMED_MACROBLOCK_SIZE)) + 1;
    _muleMetadataPixelCount =
    numRowsOfMetadata * frame.format.imageWidth * ASSUMED_MACROBLOCK_SIZE;
    bufferSize += (_muleMetadataPixelCount * 3 / 2); //1.5: bits-per-pixel (YUV)

    // make sure we've got enough data to hold the video and metadata
    _muleFrameData = realloc(_muleFrameData, bufferSize);
    _muleBufferSize = bufferSize;
    
    size_t newHeight =
    frame.format.imageHeight +
    (ASSUMED_MACROBLOCK_SIZE * numRowsOfMetadata);
    
    [_muleFrame release];
    // y u no deep copy???
    OTVideoFormat* newFormat =
    [OTVideoFormat videoFormatNV12WithWidth:frame.format.imageWidth
                                     height:newHeight];
    _muleFrame = [[OTVideoFrame alloc] initWithFormat:newFormat];
    
    uint8_t* uvPlaneAddress =
    &(_muleFrameData[newFormat.imageHeight * newFormat.imageWidth]);
    [_muleFrame.planes addPointer:_muleFrameData];
    [_muleFrame.planes addPointer:uvPlaneAddress];
}

- (void)embedMuleDataWithVideoFrame:(OTVideoFrame*)frame {
    size_t muleOffset = frame.format.imageWidth * frame.format.imageHeight;
    //size_t muleOffset = 0;
    size_t stride = _muleFrame.format.imageWidth;
    uint8_t* mule = [_muleFrame.planes pointerAtIndex:0];
    
    for (int i = 0; i < _muleData.length; i++) {
        for (int j = 0; j < ASSUMED_MACROBLOCK_SIZE; j++) {
            memset(&(mule[muleOffset + (i * ASSUMED_MACROBLOCK_SIZE) + (stride * j)]),
                   ((uint8_t*)[_muleData bytes])[i],
                   //(i << 6),
                   ASSUMED_MACROBLOCK_SIZE);
        }
    }

    // UV: sets to random colors in order to give "distinctness"
    // between macroblocks to prevent block edge bleeding during compression
    muleOffset /= 2;
    mule = [_muleFrame.planes pointerAtIndex:1];
    for (int i = 0; i < _muleData.length; i++) {
        for (int j = 0; j < ASSUMED_MACROBLOCK_SIZE / 2; j++) {
            for (int k = 0; k < ASSUMED_MACROBLOCK_SIZE; k+=2) {
                mule[muleOffset + (i * ASSUMED_MACROBLOCK_SIZE) + (stride * j) + k] = randU[i];
                mule[muleOffset + (i * ASSUMED_MACROBLOCK_SIZE) + (stride * j) + k + 1] = randV[i];
            }
        }
    }
}

- (void)copyVideoToMule:(OTVideoFrame*)frame {
    for (int i = 0; i < _muleFrame.planes.count; i++) {
        size_t bufferLength =
        [[frame.format.bytesPerRow objectAtIndex:i] intValue];
        bufferLength *= frame.format.imageHeight;
        memcpy([_muleFrame.planes pointerAtIndex:i],
               [frame.planes pointerAtIndex:i],
               bufferLength);
    }
    _muleFrame.orientation = frame.orientation;
    _muleFrame.timestamp = frame.timestamp;
}

#pragma mark - OTVideoCaptureConsumer

- (void)consumeFrame:(OTVideoFrame*)frame
{
    [self updateMuleFrameWithRealFrame:frame];
    [self copyVideoToMule:frame];
    [self embedMuleDataWithVideoFrame:frame];
    [_videoCaptureConsumer consumeFrame:_muleFrame];
}

#pragma mark - OTVideoCapture

- (void)setVideoCaptureConsumer:(id<OTVideoCaptureConsumer>)consumer
{
    _videoCaptureConsumer = consumer;
}

- (id<OTVideoCaptureConsumer>)videoCaptureConsumer {
    return _videoCaptureConsumer;
}

- (void)initCapture {
    [_videoCapture initCapture];
}

- (void)releaseCapture {
    [_videoCapture releaseCapture];
}

- (int32_t)startCapture {
    return [_videoCapture startCapture];
}

- (int32_t)stopCapture {
    return [_videoCapture stopCapture];
}

- (BOOL)isCaptureStarted {
    return [_videoCapture isCaptureStarted];
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat {
    return [_videoCapture captureSettings:videoFormat];
}

@end
