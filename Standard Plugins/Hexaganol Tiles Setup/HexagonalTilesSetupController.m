//
//  HexagonalTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HexagonalTilesSetupController.h"


@interface HexagonalTilesSetupController (PrivateMethods)
- (void)createTileOutlines;
@end


@implementation HexagonalTilesSetupController


+ (NSString *)name
{
	isalpha('a');	// get rid of weak linking warning
	return @"Hexagons";
}


- (NSView *)setupView
{
	if (!_setupView)
	{
		[NSBundle loadNibNamed:@"HexagonalTilesSetup" owner:self];

			// Update the nib with the user's last used settings.
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Hexagonal Tiles"];
		
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
    float			xSize = 1.0 / (tilesWide - 1.0/3.0), ySize = 1.0 / tilesHigh, originX, originY;
    NSBezierPath	*tileOutline;
    NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:x * y];
    
    for (x = 0; x < tilesWide; x++)
        for (y = 0; y < ((x % 2 == 0) ? tilesHigh : tilesHigh + 1); y++)
        {
            originX = xSize * (x - 1.0 / 3.0);
            originY = ySize * ((x % 2 == 0) ? y : y - 0.5);
            tileOutline = [NSBezierPath bezierPath];
            [tileOutline moveToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
                            MIN(MAX(originY, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
                            MIN(MAX(originY, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize * 4 / 3, 0) , 1),
                            MIN(MAX(originY + ySize / 2, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
                            MIN(MAX(originY + ySize, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
                            MIN(MAX(originY + ySize, 0), 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX, 0) , 1),
                            MIN(MAX(originY + ySize / 2, 0), 1))];
            [tileOutline closePath];
            [tileOutlines addObject:tileOutline];
        }
    
    [self setTileOutlines:tileOutlines];
}


@end
