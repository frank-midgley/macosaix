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
	MacOSaiXDocument	*document;
	NSImage				*mosaicImage;
	NSLock				*mosaicImageLock;
	NSAffineTransform	*mosaicImageTransform;
	BOOL				viewOriginal;	// vs. the mosaic
	
		// Tile outlines display
	BOOL				viewTileOutlines;
	NSBezierPath		*tilesOutline,
						*neighborhoodOutline;
					
		// Selected tile highlighting
    MacOSaiXTile		*highlightedTile;
    int					phase;
	
		// Queued tile view invalidation
	NSMutableArray		*tilesNeedingDisplay;
	NSDate				*lastUpdate;
	
	NSImageRep			*blackRep;
}

- (void)setDocument:(MacOSaiXDocument *)inDocument;

- (void)setViewOriginal:(BOOL)inViewOriginal;
- (BOOL)viewOriginal;

- (void)setViewTileOutlines:(BOOL)inViewTileOutlines;
- (BOOL)viewTileOutlines;

- (void)refreshTile:(MacOSaiXTile *)tileToRefresh;

	// viewHighlightedTile methods
- (void)highlightTile:(MacOSaiXTile *)tile;
- (void)animateHighlight;


@end
