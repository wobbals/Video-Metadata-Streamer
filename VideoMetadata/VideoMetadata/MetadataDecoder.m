//
//  MetadataDecoder.m
//  VideoMetadata
//
//  Created by Charley Robinson on 6/5/14.
//
//

#import "MetadataDecoder.h"
#import "MetadataConfig.h"

@implementation MetadataDecoder {
    id<OTVideoRender> _videoRender;
    
    OTVideoFrame* _demuledFrame;
}

#pragma mark - Object Lifecycle

- (id)initWithVideoRender:(id<OTVideoRender>)render
{
    self = [super init];
    if (self) {
        _videoRender = [render retain];
    }
    return self;
}

- (void)dealloc {
    [_videoRender release];
    [super dealloc];
}

#pragma mark - Private API

/** Computes the average luma for a macroblock at coordinates.
 * Coordinate units are in macroblock intervals: xReal = xMB * macroblock_size
 */
- (uint8_t)mbAverageX:(uint32_t)x Y:(uint32_t)y frame:(OTVideoFrame*)frame
{
    uint32_t total = 0;
    uint32_t stride = [[frame.format.bytesPerRow objectAtIndex:0] intValue];
    uint8_t* luma = [frame.planes pointerAtIndex:0];
    uint32_t base_mb_offset = (x * ASSUMED_MACROBLOCK_SIZE) + (stride * y * ASSUMED_MACROBLOCK_SIZE);
    for (int y_offset = 0; y_offset < ASSUMED_MACROBLOCK_SIZE; y_offset++) {
        uint32_t y_offset_real = y_offset * stride;
        for (int x_offset = 0; x_offset < ASSUMED_MACROBLOCK_SIZE; x_offset++) {
            uint32_t coord = base_mb_offset + x_offset + (y_offset_real);
            total += luma[coord];
        }
    }
    return total / (ASSUMED_MACROBLOCK_SIZE * ASSUMED_MACROBLOCK_SIZE);
}

- (BOOL)number:(int)number isWithin:(int)within of:(int)target {
    return number >= target - within && number <= target + within;
}

- (int32_t)findMagicNumber:(NSMutableArray*)vector {
    char magic[] = MULE_MAGIC_NUMBER;
    uint8_t magicSize = strlen(magic);
    uint32_t discoveryIndex = 0;
    uint8_t target = magic[discoveryIndex];
    uint32_t magicStartIndex = 0;
    uint32_t traversalIndex = 0;
    for (NSNumber* number in vector) {
        uint32_t val = ((uint8_t)[number intValue]);
        if (discoveryIndex == 0) {
            magicStartIndex = traversalIndex;
        }
        if ([self number:val isWithin:1 << MULE_DISCARD_BITS of:target]) {
            target = magic[++discoveryIndex];
        } else if (discoveryIndex > 0) {
            discoveryIndex = 0;
        }
        
        if (discoveryIndex == magicSize) {
            return magicStartIndex;
        }
        traversalIndex++;
    }
    return -1;
}

- (NSArray *)reversedArrayFromArray:(NSArray*)anArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[anArray count]];
    NSEnumerator *enumerator = [anArray reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;
}

- (void)decodeVector:(NSArray*)vector fromIndex:(int32_t)startIndex {
    char magic[] = MULE_MAGIC_NUMBER;
    uint8_t magicSize = strlen(magic);
    NSArray* decodeVector = nil;
    if (0 == startIndex) {
        decodeVector = vector;
    } else if (vector.count - magicSize == startIndex) {
        decodeVector = [self reversedArrayFromArray:vector];
    } else {
        NSLog(@"magic number not at the end of the vector?");
    }
    
    uint8_t payloadSize = [[decodeVector objectAtIndex:magicSize] intValue];
    NSMutableData* payload = [NSMutableData dataWithCapacity:payloadSize];
    uint8_t aByte;
    for (int i = magicSize + 1; i < decodeVector.count; i++) {
        aByte = [[decodeVector objectAtIndex:i] intValue];
        [payload appendBytes:&aByte length:1];
    }
    NSString* decodedPayload =
    [[[NSString alloc] initWithData:payload
                           encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"%@", decodedPayload);
}

- (void)findMuleVector:(OTVideoFrame*)frame {
    uint32_t mb_width = frame.format.imageWidth / ASSUMED_MACROBLOCK_SIZE;
    uint32_t mb_height = frame.format.imageHeight / ASSUMED_MACROBLOCK_SIZE;
    
    // walk the edges of the image
    NSMutableArray* topEW = [NSMutableArray arrayWithCapacity:mb_width];
    NSMutableArray* bottomEW = [NSMutableArray arrayWithCapacity:mb_width];
    for (int x = 0; x < mb_width; x++) {
        [topEW addObject:[NSNumber numberWithInt:[self mbAverageX:x Y:0 frame:frame]]];
        [bottomEW addObject:[NSNumber numberWithInt:[self mbAverageX:x Y:mb_height - 1 frame:frame]]];
    }

    int32_t resultIndex = [self findMagicNumber:topEW];
    if (0 <= resultIndex) {
        NSLog(@"topEW has magic number");
        [self decodeVector:topEW fromIndex:resultIndex];
    }
    
    resultIndex = [self findMagicNumber:bottomEW];
    if (0 <= resultIndex) {
        NSLog(@"bottomEW has magic number");
        [self decodeVector:bottomEW fromIndex:resultIndex];
    }
    
    NSMutableArray* leftNS = [NSMutableArray arrayWithCapacity:mb_height];
    NSMutableArray* rightNS = [NSMutableArray arrayWithCapacity:mb_height];

    for (int y = 0; y < mb_height ; y++) {
        [leftNS addObject:[NSNumber numberWithInt:[self mbAverageX:0 Y:y frame:frame]]];
        [rightNS addObject:[NSNumber numberWithInt:[self mbAverageX:mb_width - 1 Y:y frame:frame]]];
    }
    
    resultIndex = [self findMagicNumber:leftNS];
    if (0 <= resultIndex) {
        NSLog(@"leftNS has magic number");
        [self decodeVector:leftNS fromIndex:resultIndex];
    }
    
    resultIndex = [self findMagicNumber:rightNS];
    if (0 <= resultIndex) {
        NSLog(@"rightNS has magic number");
        [self decodeVector:rightNS fromIndex:resultIndex];
    }
    
}

- (void)demuleFrame:(OTVideoFrame*)frame {
    _demuledFrame = frame;
    
    [self findMuleVector:frame];
}

#pragma mark - OTVideoRender

- (void)renderVideoFrame:(OTVideoFrame*)frame {
    [self demuleFrame:frame];
    [_videoRender renderVideoFrame:_demuledFrame];
}

@end
