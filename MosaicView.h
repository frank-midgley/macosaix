//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "Tiles.h"

@interface MosaicView : NSImageView
{
    Tile*	_highlightedTile;
    int		_phase;
}

- (id)init;
- (void)mouseDown:(NSEvent *)theEvent;
- (void)highlightTile:(Tile *)tile;
- (void)animateHighlight;
- (void)drawRect:(NSRect)theRect;

@end
