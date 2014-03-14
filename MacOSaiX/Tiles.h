//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageMatch.h"


#define TILE_BITMAP_SIZE		16.0


@class MacOSaiXMosaic;


@interface MacOSaiXTile : NSObject
{
	NSBezierPath		*outline;				// The shape of this tile
	NSPoint				outlineMidPoint;
	NSMutableSet		*neighborSet;			// A set containing tiles that are considered neighbors of this tile
	NSBitmapImageRep	*bitmapRep,				// The portion of the original image that is in this tile
						*maskRep;
	NSLock				*bitmapsLock, 
						*bestMatchLock;
	MacOSaiXImageMatch	*uniqueImageMatch,
						*bestImageMatch,
						*userChosenImageMatch;	// will be nil if user has not choosen an image
	MacOSaiXMosaic		*mosaic;				// The mosaic this tile is a part of (non-retained)
	NSMutableArray		*recentUniqueImageMatches;
	NSMutableDictionary	*cachedMatches;
	BOOL				uniqueImageMatchIsOptimal;
}

	// designated initializer
- (id)initWithOutline:(NSBezierPath *)outline fromMosaic:(MacOSaiXMosaic *)inMosaic;

- (void)setNeighboringTiles:(NSArray *)neighboringTiles;
- (NSArray *)neighboringTiles;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;
- (NSPoint)outlineMidPoint;

- (NSBitmapImageRep *)bitmapRep;
- (NSBitmapImageRep *)maskRep;

- (MacOSaiXImageMatch *)uniqueImageMatch;
- (void)setUniqueImageMatch:(MacOSaiXImageMatch *)match;
- (NSArray *)recentUniqueImageMatches;
- (NSComparisonResult)compareUniqueImageMatchValue:(MacOSaiXTile *)otherTile;
- (void)setUniqueImageMatchIsOptimal:(BOOL)flag;
- (BOOL)uniqueImageMatchIsOptimal;

- (MacOSaiXImageMatch *)bestImageMatch;
- (void)setBestImageMatch:(MacOSaiXImageMatch *)match;

- (void)setUserChosenImageMatch:(MacOSaiXImageMatch *)match;
- (MacOSaiXImageMatch *)userChosenImageMatch;

- (MacOSaiXImageMatch *)displayedImageMatch;
- (void)imageSourceWasRemoved:(id<MacOSaiXImageSource>)imageSource;

- (void)reset;

@end
