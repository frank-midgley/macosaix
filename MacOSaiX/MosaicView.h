//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "Tiles.h"

typedef enum
{ _viewMosaic, _viewTilesOutline, _viewImageSources, _viewImageRegions, _viewHighlightedTile }
MosaicViewMode;

@interface MosaicView : NSView
{
	NSImage			*_originalImage, *_mosaicImage;
	MosaicViewMode	_viewMode;
	
		// ivar for _viewTileSetup
	NSBezierPath	*_tilesOutline;
	
		// ivars for viewHighlightedTile
    Tile*			_highlightedTile;
    int				_phase;
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
