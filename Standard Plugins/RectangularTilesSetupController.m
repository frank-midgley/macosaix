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
		NSString		*previousTilesWide = [defaults objectForKey:@"Tiles Wide"],
						*previousTilesHigh = [defaults objectForKey:@"Tiles High"];
		
		[NSBundle loadNibNamed:@"RectangularTilesSetup" owner:self];

		[_tilesAcrossStepper setStringValue:(previousTilesWide ? previousTilesWide : @"40")];
		_tilesWide = [_tilesAcrossStepper intValue];
		[_tilesAcrossView setIntValue:_tilesWide];
		[_tilesDownStepper setStringValue:(previousTilesHigh ? previousTilesHigh : @"40")];
		_tilesHigh = [_tilesDownStepper intValue];
		[_tilesDownView setIntValue:_tilesHigh];

		[self createTileOutlines];
	}
	return _setupView;
}


- (IBAction)setTilesAcross:(id)sender
{
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([_tilesAcrossStepper intValue] > _tilesWide)
			[_tilesAcrossStepper setIntValue:MIN(_tilesWide + 10, [_tilesAcrossStepper maxValue])];
		else
			[_tilesAcrossStepper setIntValue:MAX(_tilesWide - 10, [_tilesAcrossStepper minValue])];
	}
    _tilesWide = [_tilesAcrossStepper intValue];
    [_tilesAcrossView setIntValue:_tilesWide];
	[self createTileOutlines];
}


- (IBAction)setTilesDown:(id)sender
{
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([_tilesDownStepper intValue] > _tilesHigh)
			[_tilesDownStepper setIntValue:MIN(_tilesHigh + 10, [_tilesDownStepper maxValue])];
		else
			[_tilesDownStepper setIntValue:MAX(_tilesHigh - 10, [_tilesDownStepper minValue])];
	}
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
			{
				tileRect.origin.x = x * tileRect.size.width;
				tileRect.origin.y = y * tileRect.size.height;
//                NSBezierPath	*path = [NSBezierPath bezierPath];
//                [path moveToPoint:NSMakePoint(tileRect.origin.x, tileRect.origin.y)];
//                [path relativeLineToPoint:NSMakePoint(tileRect.size.width, 0.0)];
//                [path relativeLineToPoint:NSMakePoint(0.0, tileRect.size.height)];
//                [path lineToPoint:NSMakePoint(tileRect.origin.x, tileRect.origin.y)];
//				  [tileOutlines addObject:path];
				[tileOutlines addObject:[NSBezierPath bezierPathWithRect:tileRect]];
			}
		
		[self setTileOutlines:tileOutlines];
	}
}


@end
