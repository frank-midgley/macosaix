//
//  RectangularTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RectangularTilesSetupController.h"


@interface RectangularTilesSetupController (PrivateMethods)
- (void)createTileOutlines;
@end


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
			// First load our nib.
		[NSBundle loadNibNamed:@"RectangularTilesSetup" owner:self];

			// Update the nib with the user's last used settings.
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tiles"];
		
		int				previousTilesWide = [[plugInDefaults objectForKey:@"Tiles Wide"] intValue];
		tilesWide = (previousTilesWide > 0 && previousTilesWide <= [_tilesAcrossStepper maxValue]) ? 
						previousTilesWide : [_tilesAcrossStepper intValue];
		[_tilesAcrossStepper setIntValue:tilesWide];
		[_tilesAcrossView setIntValue:tilesWide];
		
		int				previousTilesHigh = [[plugInDefaults objectForKey:@"Tiles High"] intValue];
		tilesHigh = (previousTilesHigh > 0 && previousTilesHigh <= [_tilesDownStepper maxValue]) ? 
						previousTilesHigh : [_tilesDownStepper intValue];
		[_tilesDownStepper setIntValue:tilesHigh];
		[_tilesDownView setIntValue:tilesHigh];
		
			// Create an initial set of tile outlines based on the current settings.
		[self createTileOutlines];
	}
	
	return _setupView;
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:tilesWide], @"Tiles Wide", 
														[NSNumber numberWithInt:tilesHigh], @"Tiles High", 
														nil]
											  forKey:@"Rectangular Tiles"];
}


- (IBAction)setTilesAcross:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([_tilesAcrossStepper intValue] > tilesWide)
			[_tilesAcrossStepper setIntValue:MIN(tilesWide + 10, [_tilesAcrossStepper maxValue])];
		else if ([_tilesAcrossStepper intValue] < tilesWide)
			[_tilesAcrossStepper setIntValue:MAX(tilesWide - 10, [_tilesAcrossStepper minValue])];
	}
    tilesWide = [_tilesAcrossStepper intValue];
    [_tilesAcrossView setIntValue:tilesWide];
	
	[self updatePlugInDefaults];
	[self createTileOutlines];
}


- (IBAction)setTilesDown:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([_tilesDownStepper intValue] > tilesHigh)
			[_tilesDownStepper setIntValue:MIN(tilesHigh + 10, [_tilesDownStepper maxValue])];
		else if ([_tilesDownStepper intValue] < tilesHigh)
			[_tilesDownStepper setIntValue:MAX(tilesHigh - 10, [_tilesDownStepper minValue])];
	}
    tilesHigh = [_tilesDownStepper intValue];
    [_tilesDownView setIntValue:tilesHigh];
	
	[self updatePlugInDefaults];
	[self createTileOutlines];
}


- (void)createTileOutlines
{
	int				x, y;
	NSRect			tileRect = NSMakeRect(0, 0, 1.0 / tilesWide, 1.0 / tilesHigh);
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:x * y];
		
    for (y = tilesHigh - 1; y >= 0; y--)
		for (x = 0; x < tilesWide; x++)
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


@end
