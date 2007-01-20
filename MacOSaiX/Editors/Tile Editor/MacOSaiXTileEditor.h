//
//  MacOSaiXTileEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

@class MacOSaiXTile;


@interface MacOSaiXTileEditor : MacOSaiXEditor
{
    MacOSaiXTile			*selectedTile;
	NSTimer					*animateSelectedTileTimer;
    int						animationPhase;
}

- (void)setSelectedTile:(MacOSaiXTile *)tile;
- (MacOSaiXTile *)selectedTile;

@end
