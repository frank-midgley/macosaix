//
//  TileMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "TileImage.h"

#define WORST_CASE_PIXEL_MATCH 520200.0

@interface TileMatch : NSObject <NSCoding> {
    TileImage	*_tileImage;
    float	_matchValue;	// how well this image matched the tile
}

- (id)initWithTileImage:(TileImage *)tileImage matchValue:(float)matchValue;
- (void)setTileImage:(TileImage *)tileImage;
- (TileImage *)tileImage;
- (void)setMatchValue:(float)matchValue;
- (float)matchValue;

@end
