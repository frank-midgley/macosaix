//
//  RectangularTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "RectangularTilesSetupController.h"


@implementation RectangularTilesSetupController


- (id)init
{
	self = [super init];
	if (self)
	{
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		
		[_tilesAcrossStepper setStringValue:[defaults objectForKey:@"Tiles Wide"]];
		_tilesWide = [_tilesAcrossStepper intValue];
		[_tilesAcrossView setIntValue:_tilesWide];
		[_tilesDownStepper setStringValue:[defaults objectForKey:@"Tiles High"]];
		_tilesHigh = [_tilesDownStepper intValue];
		[_tilesDownView setIntValue:_tilesHigh];
	}
	return self;
}


- (NSView *)setupView
{
	if (!_setupView)
		[NSBundle loadNibNamed:@"RectangularTilesSetup" owner:self];
	return _setupView;
}


- (void)setTilesAcross:(id)sender
{
    _tilesWide = [_tilesAcrossStepper intValue];
    [_tilesAcrossView setIntValue:_tilesWide];
}


- (void)setTilesDown:(id)sender
{
    _tilesHigh = [_tilesDownStepper intValue];
    [_tilesDownView setIntValue:_tilesHigh];
}


@end
