//
//  RectangularTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RectangularTilesSetupController.h"


@implementation RectangularTilesSetupController


+ (NSString *)name
{
	isalpha('a');	// get rid of weak linking warning
	return @"Rectangles";
}


- (NSView *)setupView
{
	if (!_setupView)
	{
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		
		[NSBundle loadNibNamed:@"RectangularTilesSetup" owner:self];

//		[_tilesAcrossStepper setStringValue:[defaults objectForKey:@"Tiles Wide"]];
		_tilesWide = [_tilesAcrossStepper intValue];
		[_tilesAcrossView setIntValue:_tilesWide];
//		[_tilesDownStepper setStringValue:[defaults objectForKey:@"Tiles High"]];
		_tilesHigh = [_tilesDownStepper intValue];
		[_tilesDownView setIntValue:_tilesHigh];

		[self createTileOutlines];
	}
	return _setupView;
}


- (void)setTilesAcross:(id)sender
{
    _tilesWide = [_tilesAcrossStepper intValue];
    [_tilesAcrossView setIntValue:_tilesWide];
	[self createTileOutlines];
}


- (void)setTilesDown:(id)sender
{
    _tilesHigh = [_tilesDownStepper intValue];
    [_tilesDownView setIntValue:_tilesHigh];
	[self createTileOutlines];
}


- (void)createTileOutlines
{
	if (_tilesWide > 0 && _tilesHigh > 0)
	{
		int				x, y;
		NSRect			tileRect = NSMakeRect(0, 0, 1.0 / _tilesWide, 1.0 / _tilesHigh);
		NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:x * y];
		
    for (y = _tilesHigh - 1; y >= 0; y--)
		for (x = 0; x < _tilesWide; x++)
//			for (y = 0; y < _tilesHigh; y++)
			{
				tileRect.origin.x = x * tileRect.size.width;
				tileRect.origin.y = y * tileRect.size.height;
				[tileOutlines addObject:[NSBezierPath bezierPathWithRect:tileRect]];
			}
		
		[self setTileOutlines:tileOutlines];
	}
}


@end
