//
//  ErrorCorrection.m
//  VideoMetadata
//
//  Created by Charley Robinson on 6/6/14.
//
//

#import "ForwardErrorCorrection.h"
#import "MetadataConfig.h"

@implementation ForwardErrorCorrection

+ (NSData*)encodeTruncationExpansionWithData:(NSData*)data {
    uint8_t encodedBitsPerByte = 8 - MULE_DISCARD_BITS;
    const uint8_t encodedMask = (uint8_t)(0xFF << MULE_DISCARD_BITS);
    size_t encodedLength =
    ceil((double)data.length * 8.0 / (double)(encodedBitsPerByte));
    // add single-byte padding so we can overflow the read without segfaulting
    NSMutableData* uncodedData = [NSMutableData dataWithCapacity:data.length + 1];
    [uncodedData appendData:data];
    NSMutableData* encodedData = [[[NSMutableData alloc]
                                  initWithCapacity:encodedLength] autorelease];
    uint8_t encodedByte = 0;
    uint32_t bitsPushed = 0;
    uint8_t* dataPtr = (uint8_t*)[uncodedData bytes];
    uint8_t* encodedPtr = (uint8_t*)[encodedData bytes];
    uint8_t currentByte = dataPtr[0];
    uint16_t currentUnencodedBytes = currentByte << 8;
    uint32_t index = 0;
    uint16_t unencodedCurrentBits = 8;
    while (bitsPushed <= data.length * 8) {
        // while the currentUnencodedBytes holder has unpacked bits
        while (unencodedCurrentBits >= 8) {
            // pack the MSB into the encode buffer
            encodedByte = ((currentUnencodedBytes >> 8) & encodedMask);
            [encodedData appendBytes:&encodedByte length:1];
            // count the bits packed
            bitsPushed += encodedBitsPerByte;
            unencodedCurrentBits -= encodedBitsPerByte;
            // shift out the bits that have been transfered to encode buffer
            currentUnencodedBytes <<= encodedBitsPerByte;
        }
        // get another byte, push it onto currentUnencodedBytes
        currentByte = dataPtr[++index];
        currentUnencodedBytes |= (currentByte << (8 - unencodedCurrentBits));
        // increment bit counter by the amount we pushed
        unencodedCurrentBits += 8;
        
    }
    return encodedData;
}

+ (NSData*)decodeTruncationExpansionWithData:(NSData*)data {
    uint8_t bitsPerEncodedByte = 8 - MULE_DISCARD_BITS;
    size_t decodedLength =
    floor((double)data.length * (double)(bitsPerEncodedByte) / 8.0);
    // add single-byte padding so we can overflow the read without segfaulting
    NSMutableData* encodedData =
    [NSMutableData dataWithCapacity:data.length + 1];
    // first, round all encoded bytes to nearest DISCARD_BITS value
    uint8_t* dataPtr = (uint8_t*)[data bytes];
    uint32_t roundPow = pow(2, MULE_DISCARD_BITS);
    for (int i = 0; i < data.length; i++) {
        uint8_t aByte = dataPtr[i];
        aByte = round((double)aByte / (double) roundPow) * roundPow;
        [encodedData appendBytes:&aByte length:1];
    }
    
    NSMutableData* decodedData =
    [[[NSMutableData alloc] initWithCapacity:decodedLength] autorelease];
    
    dataPtr = (uint8_t*)[encodedData bytes];
    uint8_t currentByte = dataPtr[0];
    uint16_t currentBytes = 0;
    uint16_t nextByte = 0;
    uint8_t decodedByte = 0;
    uint16_t nextLeftShift = 0;
    uint16_t nextByteRemainingEncodedBits;
    uint16_t currentByteDecodedBits = bitsPerEncodedByte;
    for (int index = 1; index < encodedData.length; index++) {
        nextByte = dataPtr[index];
        nextByteRemainingEncodedBits = bitsPerEncodedByte;
        // if both current and next bytes have useable bits
        if (currentByteDecodedBits) {
            // push current bits to MSB
            currentBytes = currentByte << 8;
            // calculate bits needed from nextByte
            nextLeftShift = (8 - currentByteDecodedBits) % 8;
            // if used this time, useless next time. decrement as such
            nextByteRemainingEncodedBits -= nextLeftShift;
            // shift remaining encoded bits to MSB
            currentBytes |= nextByte << nextLeftShift;
            // MSB has a full byte, pop it off and add to decode bufffer
            decodedByte = currentBytes >> 8;
            [decodedData appendBytes:&decodedByte length:1];
            // pop used bits from nextByte
            nextByte <<= nextLeftShift;
        }
        currentByte = nextByte;
        currentByteDecodedBits = nextByteRemainingEncodedBits;
    }
    
    return decodedData;
}


@end
