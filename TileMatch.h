//
//  TileMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#define WORST_CASE_PIXEL_MATCH 520200.0

@interface TileMatch : NSObject {
    NSURL*		_imageURL;	// where the image is located
    NSBitmapImageRep*	_bitmapRep;	// low res version of the image
    double		_matchValue;	// how well this image matched the tile
}

- (void)setImageURL:(NSURL *)imageURL;
- (NSURL *)imageURL;
- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep;
- (NSBitmapImageRep *)bitmapRep;
- (void)setMatchValue:(double)matchValue;
- (double)matchValue;

@end
