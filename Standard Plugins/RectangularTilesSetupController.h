//
//  RectangularTilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/TilesSetupController.h>


@interface RectangularTilesSetupController : TilesSetupController
{
    IBOutlet NSTextField	*_tilesAcrossView, *_tilesDownView;
    IBOutlet NSStepper		*_tilesAcrossStepper, *_tilesDownStepper;
	unsigned int			_tilesWide, _tilesHigh;
}

- (void)setTilesAcross:(id)sender;
- (void)setTilesDown:(id)sender;

@end
