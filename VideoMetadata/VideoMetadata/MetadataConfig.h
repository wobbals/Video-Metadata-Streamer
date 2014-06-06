//
//  MetadataConfig.h
//  VideoMetadata
//
//  Created by Charley Robinson on 6/6/14.
//
//

#ifndef VideoMetadata_MetadataConfig_h
#define VideoMetadata_MetadataConfig_h

// This is at least true for vp8 and h.264, which hopefully covers our usage.
#define ASSUMED_MACROBLOCK_SIZE 16

// Symmetric magic number we'll look for to identify the data sequence
#define MULE_MAGIC_NUMBER { 0x9F, 0x75, 0xF2, 0x75, 0x9F, 0x00 }

#define MULE_DISCARD_BITS 2

#endif
