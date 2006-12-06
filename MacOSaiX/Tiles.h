//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageMatch.h"


#define TILE_BITMAP_SIZE		128.0


@class MacOSaiXMosaic;


@interface MacOSaiXTile : NSObject
{
	NSBezierPath		*unitOutline;			// The shape of this tile
	float				imageOrientation;		// The orientation of this tile (in degrees)
	
	NSBitmapImageRep	*bitmapRep,				// The portion of the original image that is in this tile
						*maskRep;
	
	MacOSaiXImageMatch	*uniqueImageMatch,
						*bestImageMatch,
						*userChosenImageMatch;	// will be nil if user has not choosen an image
	
	MacOSaiXMosaic		*mosaic;				// The mosaic this tile is a part of (non-retained)
}

	// designated initializer
- (id)initWithUnitOutline:(NSBezierPath *)outline 
		 imageOrientation:(float)angle
				   mosaic:(MacOSaiXMosaic *)mosaic;

- (void)setImageOrientation:(float)angle;
- (float)imageOrientation;

- (void)setMosaic:(MacOSaiXMosaic *)mosaic;
- (MacOSaiXMosaic *)mosaic;

- (void)setUnitOutline:(NSBezierPath *)outline;
- (NSBezierPath *)unitOutline;
- (NSBezierPath *)originalOutline;
- (NSBezierPath *)rotatedOriginalOutline;

- (NSBitmapImageRep *)bitmapRep;
- (NSBitmapImageRep *)maskRep;
- (void)resetBitmapRepAndMask;

- (MacOSaiXImageMatch *)uniqueImageMatch;
- (void)setUniqueImageMatch:(MacOSaiXImageMatch *)match;

- (MacOSaiXImageMatch *)bestImageMatch;
- (void)setBestImageMatch:(MacOSaiXImageMatch *)match;

- (void)setUserChosenImageMatch:(MacOSaiXImageMatch *)match;
- (MacOSaiXImageMatch *)userChosenImageMatch;

- (MacOSaiXImageMatch *)displayedImageMatch;

@end
