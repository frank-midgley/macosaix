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
	
		// Queued tile view invalidation
	NSMutableArray			*tilesNeedingDisplay;
	NSLock					*tilesNeedingDisplayLock;
	NSDate					*lastUpdate;
	
	NSImageRep				*blackRep;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;

- (void)setViewFade:(float)fade;
- (float)fade;

- (void)setViewTileOutlines:(BOOL)inViewTileOutlines;
- (BOOL)viewTileOutlines;

- (void)refreshTile:(MacOSaiXTile *)tileToRefresh previousMatch:(MacOSaiXImageMatch *)previousMatch;

	// Highlight methods
- (void)highlightTile:(MacOSaiXTile *)tile;
- (void)highlightImageSources:(NSArray *)imageSources;
- (void)animateHighlight;

- (NSImage *)image;

@end
