//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 MyCompanyName. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXDocument.h"
#import "Tiles.h"

typedef enum
{ viewMosaic, viewTilesOutline, viewImageSources, viewImageRegions, viewHighlightedTile }
MosaicViewMode;

@interface MosaicView : NSView
{
	MacOSaiXDocument	*document;
	NSImage				*mosaicImage;
	NSLock				*mosaicImageLock;
	NSAffineTransform	*mosaicImageTransform;
	MosaicViewMode		viewMode;
	
		// ivar for viewTileSetup
	NSBezierPath		*tilesOutline,
						*neighborhoodOutline;
					
		// ivars for viewHighlightedTile
    Tile*				highlightedTile;
    int					phase;
	
	NSMutableArray		*tilesNeedingDisplay;
}

- (void)setDocument:(MacOSaiXDocument *)inDocument;

- (void)setViewMode:(MosaicViewMode)mode;
- (MosaicViewMode)viewMode;

	// viewHighlightedTile methods
- (void)highlightTile:(Tile *)tile;
- (void)animateHighlight;


@end
