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


typedef enum { showOriginalMode = 0, showNonUniqueMode, showBlackMode } MacOSaiXNonUniqueTileDisplayMode;


@interface MosaicView : NSView
{
	MacOSaiXMosaic			*mosaic;
	NSImage					*mosaicImage;
	NSLock					*mosaicImageLock;
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
	
	MacOSaiXNonUniqueTileDisplayMode	nonUniqueTileDisplayMode;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;

- (void)setViewFade:(float)fade;
- (float)fade;

- (void)setViewTileOutlines:(BOOL)inViewTileOutlines;
- (BOOL)viewTileOutlines;

- (void)setNonUniqueTileDisplayMode:(MacOSaiXNonUniqueTileDisplayMode)mode;
- (MacOSaiXNonUniqueTileDisplayMode)nonUniqueTileDisplayMode;

	// Highlight methods
- (void)highlightTile:(MacOSaiXTile *)tile;
- (void)highlightImageSources:(NSArray *)imageSources;
- (void)animateHighlight;

- (NSImage *)image;

@end
