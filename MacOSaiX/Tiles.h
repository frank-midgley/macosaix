//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 _CompanyName__. All rights reserved.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"

#define TILE_BITMAP_SIZE 32.0


@interface ImageMatch : NSObject
{
    float					matchValue;
    id<MacOSaiXImageSource>	imageSource;
	NSString				*imageIdentifier;
}
- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(NSString *)inImageIdentifier 
		 fromImageSource:(id<MacOSaiXImageSource>)inImageSource;
- (float)matchValue;
- (id<MacOSaiXImageSource>)imageSource;
- (NSString *)imageIdentifier;
@end


#define WORST_CASE_PIXEL_MATCH 520200.0


@interface Tile : NSObject
{
    NSBezierPath		*outline;				// The shape of this tile
	NSMutableSet		*neighborSet;			// A set containing tiles that are considered neighbors of this tile
    NSBitmapImageRep	*bitmapRep,				// The portion of the original image that is in this tile
                        *maskRep;
    NSMutableArray		*imageMatches;			// Array of ImageMatches
    NSLock				*imageMatchesLock,		// thread safety
                        *bestMatchLock;
    ImageMatch			*bestImageMatch,
						*userChosenImageMatch;	// will be nil if user has not choosen an image
    int					maxMatches;
    NSDocument			*document;				// The document this tile is a part of
}

	// designated initializer
- (id)initWithOutline:(NSBezierPath *)outline fromDocument:(NSDocument *)document;

- (void)setNeighbors:(NSArray *)neighboringTiles;
- (void)addNeighbor:(Tile *)neighboringTile;
- (void)addNeighbors:(NSArray *)neighboringTiles;
- (void)removeNeighbor:(Tile *)nonNeighboringTile;
- (NSArray *)neighbors;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;

- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep withMask:(NSBitmapImageRep *)maskRep;
- (NSBitmapImageRep *)bitmapRep;

- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep
			  withIdentifier:(NSString *)imageIdentifier
		     fromImageSource:(id<MacOSaiXImageSource>)imageSource;
//- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep fromCachedImage:(CachedImage *)cachedImage
//				  forDocument:(NSDocument *)document;

- (ImageMatch *)displayedImageMatch;
- (BOOL)calculateBestMatch;

- (void)setUserChosenImageIdentifer:(NSString *)imageIdentifier fromImageSource:(id<MacOSaiXImageSource>)imageSource;
- (ImageMatch *)userChosenImageMatch;

- (NSArray *)matches;
- (int)matchCount;

- (float)matchValueForImageIdentifer:(NSString *)imageIdentifier fromImageSource:(id<MacOSaiXImageSource>)imageSource;

@end
