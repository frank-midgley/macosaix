//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-5 Frank M. Midgley.  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXMosaic.h"
#import "Tiles.h"


typedef enum { blackMode = 0, originalMode, nonUniqueMode, clearMode } MacOSaiXBackgroundMode;


@interface MosaicView : NSView
{
	MacOSaiXMosaic			*mosaic;
	NSImage					*mosaicImage, 
							*nonUniqueImage;
	NSLock					*mosaicImageLock, 
							*nonUniqueImageLock;
	NSAffineTransform		*mosaicImageTransform;
	float					viewFade;
	
		// Tile outlines display
	BOOL					viewTileOutlines;
	NSBezierPath			*tilesOutline;
					
		// Selected tile highlighting
    MacOSaiXTile			*highlightedTile;
	NSArray					*highlightedImageSources;
	NSLock					*highlightedImageSourcesLock;
	NSBezierPath			*highlightedImageSourcesOutline;
    int						phase;
	
		// Tile refreshing
	NSMutableArray			*tilesToRefresh;
	NSLock					*tileRefreshLock;
	BOOL					refreshingTiles;
	
		// Queued tile view invalidation
	NSMutableArray			*tilesNeedingDisplay;
	NSLock					*tilesNeedDisplayLock;
	NSTimer					*tilesNeedDisplayTimer;
	
	NSImageRep				*blackRep;
	
	MacOSaiXBackgroundMode	backgroundMode;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;

- (void)setMosaicImage:(NSImage *)image;
- (NSImage *)mosaicImage;
- (void)setNonUniqueImage:(NSImage *)image;
- (NSImage *)nonUniqueImage;

- (void)setFade:(float)fade;
- (float)fade;

- (void)setViewTileOutlines:(BOOL)inViewTileOutlines;
- (BOOL)viewTileOutlines;

- (void)setBackgroundMode:(MacOSaiXBackgroundMode)mode;
- (MacOSaiXBackgroundMode)backgroundMode;

	// Highlight methods
- (void)highlightTile:(MacOSaiXTile *)tile;
- (void)highlightImageSources:(NSArray *)imageSources;
- (void)animateHighlight;

- (NSImage *)image;

@end
