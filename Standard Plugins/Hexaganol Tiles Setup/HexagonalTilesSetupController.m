//
//  HexagonalTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HexagonalTilesSetupController.h"


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
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		
		[NSBundle loadNibNamed:@"HexagonalTilesSetup" owner:self];

//		[_tilesAcrossStepper setStringValue:[defaults objectForKey:@"Tiles Wide"]];
        [_tilesAcrossStepper setIntValue:53];
		_tilesWide = [_tilesAcrossStepper intValue];
		[_tilesAcrossView setIntValue:_tilesWide];
//		[_tilesDownStepper setStringValue:[defaults objectForKey:@"Tiles High"]];
        [_tilesDownStepper setIntValue:30];
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
    int				x, y;
    float			xSize = 1.0 / (_tilesWide - 1.0/3.0), ySize = 1.0 / _tilesHigh, originX, originY;
    NSBezierPath	*tileOutline;
    NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:x * y];
    
    for (x = 0; x < _tilesWide; x++)
        for (y = 0; y < ((x % 2 == 0) ? _tilesHigh : _tilesHigh + 1); y++)
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
