//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 _CompanyName__. All rights reserved.

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"


#define TILE_BITMAP_SIZE 16.0


@class MacOSaiXTile;
@class MacOSaiXDocument;

@interface MacOSaiXImageMatch : NSObject
{
    float					matchValue;
    id<MacOSaiXImageSource>	imageSource;
	NSString				*imageIdentifier;
	MacOSaiXTile			*tile;
}

- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(NSString *)inImageIdentifier 
		 fromImageSource:(id<MacOSaiXImageSource>)inImageSource
				 forTile:(MacOSaiXTile *)inTile;
- (float)matchValue;
- (id<MacOSaiXImageSource>)imageSource;
- (NSString *)imageIdentifier;
- (MacOSaiXTile *)tile;
- (void)setTile:(MacOSaiXTile *)inTile;
- (NSComparisonResult)compare:(MacOSaiXImageMatch *)otherMatch;

@end


#define WORST_CASE_PIXEL_MATCH 520200.0


@interface MacOSaiXTile : NSObject
{
	NSBezierPath		*outline;				// The shape of this tile
	NSMutableSet		*neighborSet;			// A set containing tiles that are considered neighbors of this tile
	NSMutableDictionary	*imagesInUseByNeighbors;
	NSBitmapImageRep	*bitmapRep,				// The portion of the original image that is in this tile
						*maskRep;
	MacOSaiXImageMatch	*imageMatch,
						*nonUniqueImageMatch,
						*userChosenImageMatch;	// will be nil if user has not choosen an image
	MacOSaiXDocument	*document;				// The document this tile is a part of (non-retained)
//	NSMutableDictionary	*cachedMatches;
//	NSMutableArray		*cachedMatchesOrder;
}

	// designated initializer
- (id)initWithOutline:(NSBezierPath *)outline fromDocument:(MacOSaiXDocument *)document;

- (void)setNeighboringTiles:(NSArray *)neighboringTiles;
- (NSArray *)neighboringTiles;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;

- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep withMask:(NSBitmapImageRep *)maskRep;
- (NSBitmapImageRep *)bitmapRep;

- (float)matchValueForImageRep:(NSBitmapImageRep *)matchRep
			    withIdentifier:(NSString *)imageIdentifier
			   fromImageSource:(id<MacOSaiXImageSource>)imageSource;
//- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep
//			  withIdentifier:(NSString *)imageIdentifier
//		     fromImageSource:(id<MacOSaiXImageSource>)imageSource;
//- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep fromCachedImage:(CachedImage *)cachedImage
//				  forDocument:(NSDocument *)document;

- (MacOSaiXImageMatch *)imageMatch;
- (void)setImageMatch:(MacOSaiXImageMatch *)match;

- (void)setUserChosenImageIdentifer:(NSString *)imageIdentifier fromImageSource:(id<MacOSaiXImageSource>)imageSource;
- (MacOSaiXImageMatch *)userChosenImageMatch;

- (MacOSaiXImageMatch *)displayedImageMatch;

@end
