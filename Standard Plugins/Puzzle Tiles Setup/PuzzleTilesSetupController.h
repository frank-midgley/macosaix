//
//  PuzzleTilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Mon Oct 11 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/TilesSetupController.h>


@interface PuzzleTilesSetupController : TilesSetupController
{
    IBOutlet NSTextField	*tilesAcrossView, *tilesDownView;
    IBOutlet NSStepper		*tilesAcrossStepper, *tilesDownStepper;
	unsigned int			tilesWide, tilesHigh;
}

- (void)setTilesAcross:(id)sender;
- (void)setTilesDown:(id)sender;

@end
