//
//  PuzzleTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Mon Oct 11 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PuzzleTilesSetupController.h"
#import <unistd.h>
#import <fcntl.h>


@interface PuzzleTilesSetupController (PrivateMethods)
- (void)createTileOutlines;
@end


@implementation PuzzleTilesSetupController


+ (NSString *)name
{
	isalpha('a');	// get rid of weak linking warning
	return @"Puzzle Pieces";
}


- (NSView *)setupView
{
	if (!_setupView)
	{
		[NSBundle loadNibNamed:@"PuzzleTilesSetup" owner:self];

			// Update the nib with the user's last used settings.
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Puzzle Tiles"];
		
		int				previousTilesWide = [[plugInDefaults objectForKey:@"Tiles Wide"] intValue];
		tilesWide = (previousTilesWide > 0 && previousTilesWide <= [tilesAcrossStepper maxValue]) ? 
						previousTilesWide : [tilesAcrossStepper intValue];
		[tilesAcrossStepper setIntValue:tilesWide];
		[tilesAcrossView setIntValue:tilesWide];
		
		int				previousTilesHigh = [[plugInDefaults objectForKey:@"Tiles High"] intValue];
		tilesHigh = (previousTilesHigh > 0 && previousTilesHigh <= [tilesDownStepper maxValue]) ? 
						previousTilesHigh : [tilesDownStepper intValue];
		[tilesDownStepper setIntValue:tilesHigh];
		[tilesDownView setIntValue:tilesHigh];
		
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
											  forKey:@"Puzzle Tiles"];
}


- (IBAction)setTilesAcross:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([tilesAcrossStepper intValue] > tilesWide)
			[tilesAcrossStepper setIntValue:MIN(tilesWide + 10, [tilesAcrossStepper maxValue])];
		else if ([tilesAcrossStepper intValue] < tilesWide)
			[tilesAcrossStepper setIntValue:MAX(tilesWide - 10, [tilesAcrossStepper minValue])];
	}
	tilesWide = [tilesAcrossStepper intValue];
	[tilesAcrossView setIntValue:tilesWide];
	
	[self updatePlugInDefaults];
	[self createTileOutlines];
}


- (IBAction)setTilesDown:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([tilesDownStepper intValue] > tilesHigh)
			[tilesDownStepper setIntValue:MIN(tilesHigh + 10, [tilesDownStepper maxValue])];
		else if ([tilesDownStepper intValue] < tilesHigh)
			[tilesDownStepper setIntValue:MAX(tilesHigh - 10, [tilesDownStepper minValue])];
	}
	tilesHigh = [tilesDownStepper intValue];
	[tilesDownView setIntValue:tilesHigh];
	
	[self updatePlugInDefaults];
	[self createTileOutlines];
}


- (void)createTileOutlines
{
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(tilesWide * tilesHigh)];
	int				rand_fd = open("/dev/random", O_RDONLY, 0), x, y, orientation;
	float			xSize = 1.0 / tilesWide, ySize = 1.0 / tilesHigh, originX, originY;
	BOOL			tabs[tilesWide * 2 + 1][tilesHigh];

	// decide which way all of the tabs will point
	for (x = 0; x < tilesWide * 2 + 1; x++)
		for (y = 0; y < tilesHigh; y++)
		{
			int random_number;
			
			read(rand_fd, &random_number, sizeof(random_number));
			tabs[x][y] = (random_number % 2 == 0);
		}
	    
	for (x = 0; x < tilesWide; x++)
		for (y = 0; y < tilesHigh; y++)
		{
			NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
			
			originX = xSize * x;
			originY = ySize * y;
			[tileOutline moveToPoint:NSMakePoint(originX, originY)];
			
			if (y > 0)
			{
				orientation = (tabs[x * 2][y - 1] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize / 4, originY)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 5 / 12,
													  originY + ySize / 6 * orientation)
							controlPoint1:NSMakePoint(originX + xSize / 3,
													  originY)
							controlPoint2:NSMakePoint(originX + xSize / 2,
													  originY + ySize / 12 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 2,
													  originY + ySize / 3 * orientation)
							controlPoint1:NSMakePoint(originX + xSize / 3,
													  originY + ySize / 4 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 3 / 8,
													  originY + ySize / 3 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 7 / 12,
													  originY + ySize / 6 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 15 / 24,
													  originY + ySize / 3 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 2 / 3,
													  originY + ySize / 4 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 3 / 4,
													  originY)
							controlPoint1:NSMakePoint(originX + xSize / 2,
													  originY + ySize / 12 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 2 / 3,
													  originY)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY)];
			if (x < tilesWide - 1)
			{
				orientation = (tabs[x * 2 + 1][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY + ySize / 4)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + xSize / 6 * orientation,
													  originY + ySize * 5 / 12)
							controlPoint1:NSMakePoint(originX + xSize,
													  originY + ySize / 3)
							controlPoint2:NSMakePoint(originX + xSize + xSize / 12 * orientation,
													  originY + ySize / 2)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + xSize / 3 * orientation,
													  originY + ySize / 2)
							controlPoint1:NSMakePoint(originX + xSize + xSize / 4 * orientation,
													  originY + ySize / 3)
							controlPoint2:NSMakePoint(originX + xSize + xSize / 3 * orientation,
													  originY + ySize * 3 / 8)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + xSize / 6 * orientation,
													  originY + ySize * 7 / 12)
							controlPoint1:NSMakePoint(originX + xSize + xSize / 3 * orientation,
													  originY + ySize * 15 / 24)
							controlPoint2:NSMakePoint(originX + xSize + xSize / 4 * orientation,
													  originY + ySize * 2 / 3)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize,
													  originY + ySize * 3 / 4)
							controlPoint1:NSMakePoint(originX + xSize + xSize / 12 * orientation,
													  originY + ySize / 2)
							controlPoint2:NSMakePoint(originX + xSize,
													  originY + ySize * 2 / 3)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY + ySize)];
			if (y < tilesHigh - 1)
			{
				orientation = (tabs[x * 2][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize * 3 / 4, originY + ySize)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 7 / 12,
													  originY + ySize + ySize / 6 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 2 / 3,
													  originY + ySize)
							controlPoint2:NSMakePoint(originX + xSize / 2,
													  originY + ySize + ySize / 12 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 2,
													  originY + ySize + ySize / 3 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 2 / 3,
													  originY + ySize + ySize / 4 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 15 / 24,
													  originY + ySize + ySize / 3 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 5 / 12,
													  originY + ySize + ySize / 6 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 3 / 8,
													  originY + ySize + ySize / 3 * orientation)
							controlPoint2:NSMakePoint(originX + xSize / 3,
													  originY + ySize + ySize / 4 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 4,
													  originY + ySize)
							controlPoint1:NSMakePoint(originX + xSize / 2,
													  originY + ySize + ySize / 12 * orientation)
							controlPoint2:NSMakePoint(originX + xSize / 3,
													  originY + ySize)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX, originY + ySize)];
			if (x > 0)
			{
				orientation = (tabs[x * 2 - 1][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX, originY + ySize * 3 / 4)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 6 * orientation,
													  originY + ySize * 7 / 12)
							controlPoint1:NSMakePoint(originX,
													  originY + ySize * 2 / 3)
							controlPoint2:NSMakePoint(originX + xSize / 12 * orientation,
													  originY + ySize / 2)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 3 * orientation,
													  originY + ySize / 2)
							controlPoint1:NSMakePoint(originX + xSize / 4 * orientation,
													  originY + ySize * 2 / 3)
							controlPoint2:NSMakePoint(originX + xSize / 3 * orientation,
													  originY + ySize * 15 / 24)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 6 * orientation,
													  originY + ySize * 5 / 12)
							controlPoint1:NSMakePoint(originX + xSize / 3 * orientation,
													  originY + ySize * 3 / 8)
							controlPoint2:NSMakePoint(originX + xSize / 4 * orientation,
													  originY + ySize / 3)];
				[tileOutline curveToPoint:NSMakePoint(originX,
													  originY + ySize / 4)
							controlPoint1:NSMakePoint(originX + xSize / 12 * orientation,
													  originY + ySize / 2)
							controlPoint2:NSMakePoint(originX,
													  originY + ySize / 3)];
			}
			[tileOutline closePath];
			[tileOutlines addObject:tileOutline];
		}
	
	close(rand_fd);
	
	[self setTileOutlines:tileOutlines];
}


@end
