//
//  HexagonalTilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Oct 5 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/TilesSetupController.h>


@interface HexagonalTilesSetupController : TilesSetupController
{
    IBOutlet NSTextField	*_tilesAcrossView, *_tilesDownView;
    IBOutlet NSStepper		*_tilesAcrossStepper, *_tilesDownStepper;
	unsigned int			tilesWide, tilesHigh;
}

- (void)setTilesAcross:(id)sender;
- (void)setTilesDown:(id)sender;

@end
