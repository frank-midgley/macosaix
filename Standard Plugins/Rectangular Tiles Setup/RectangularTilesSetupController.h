//
//  RectangularTilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/TilesSetupController.h>


@interface RectangularTilesSetupController : TilesSetupController
{
    IBOutlet NSTextField	*_tilesAcrossView, *_tilesDownView;
    IBOutlet NSStepper		*_tilesAcrossStepper, *_tilesDownStepper;
	unsigned int			tilesWide, tilesHigh;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

@end
