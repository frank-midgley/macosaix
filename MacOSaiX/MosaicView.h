//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-5 Frank M. Midgley.  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXDocument.h"
#import "Tiles.h"


@interface MosaicView : NSView
{
	MacOSaiXDocument		*document;
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
	NSBezierPath			*highlightedImageSourcesOutline;
    int						phase;
	
		// Queued tile view invalidation
	NSMutableArray			*tilesNeedingDisplay;
	NSLock					*tilesNeedingDisplayLock;
	NSDate					*lastUpdate;
	
	NSImageRep				*blackRep;
}

- (void)setDocument:(MacOSaiXDocument *)inDocument;

- (void)setViewFade:(float)fade;
- (float)fade;

- (void)setViewTileOutlines:(BOOL)inViewTileOutlines;
- (BOOL)viewTileOutlines;

- (void)refreshTile:(MacOSaiXTile *)tileToRefresh;

	// Highlight methods
- (void)highlightTile:(MacOSaiXTile *)tile;
- (void)highlightImageSources:(NSArray *)imageSources;
- (void)animateHighlight;


@end
