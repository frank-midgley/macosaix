//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 MyCompanyName. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "Tiles.h"

typedef enum
{ viewMosaic, viewTilesOutline, viewImageSources, viewImageRegions, viewHighlightedTile }
MosaicViewMode;

@interface MosaicView : NSView
{
	NSImage			*originalImage, *mosaicImage;
	MosaicViewMode	viewMode;
	
		// ivar for viewTileSetup
	NSBezierPath	*tilesOutline,
					*neighborhoodOutline;
					
		// ivars for viewHighlightedTile
    Tile*			highlightedTile;
    int				phase;
}

- (id)init;
- (void)setOriginalImage:(NSImage *)originalImage;
- (void)setMosaicImage:(NSImage *)mosaicImage;
- (void)setViewMode:(MosaicViewMode)mode;
- (MosaicViewMode)viewMode;
- (void)mouseDown:(NSEvent *)theEvent;
- (void)drawRect:(NSRect)theRect;

	// viewTileSetup methods
- (void)setTileOutlines:(NSArray *)tileOutlines;

	// viewHighlightedTile methods
- (void)highlightTile:(Tile *)tile;
- (void)animateHighlight;


@end
