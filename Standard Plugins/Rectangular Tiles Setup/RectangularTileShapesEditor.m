//
//  RectangularTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RectangularTileShapesEditor.h"


@implementation MacOSaiXRectangularTileShapesEditor


+ (NSString *)name
{
	return @"Rectangles";
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"RectangularTileShapes" owner:self];
	
	return editorView;
}


- (void)setCurrentTileShapes:(id<MacOSaiXTileShapes>)tileShapes
{
	[currentTileShapes autorelease];
	currentTileShapes = [tileShapes retain];
}


- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup forOriginalImage:(NSImage *)originalImage
{
	[self setCurrentTileShapes:tilesSetup];
	
		// Constrain the tiles across value to the stepper's range and update the model and view.
	int	tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossStepper minValue]), [tilesAcrossStepper maxValue]);
	[currentTileShapes setTilesAcross:tilesAcross];
	[tilesAcrossStepper setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	
		// Constrain the tiles down value to the stepper's range and update the model and view.
	int	tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownStepper minValue]), [tilesDownStepper maxValue]);
	[currentTileShapes setTilesDown:tilesDown];
	[tilesDownStepper setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes tilesAcross]], @"Tiles Across", 
														[NSNumber numberWithInt:[currentTileShapes tilesDown]], @"Tiles Down", 
														nil]
											  forKey:@"Rectangular Tiles"];
}


- (IBAction)setTilesAcross:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([tilesAcrossStepper intValue] > [currentTileShapes tilesAcross])
			[tilesAcrossStepper setIntValue:MIN([currentTileShapes tilesAcross] + 10, [tilesAcrossStepper maxValue])];
		else if ([tilesAcrossStepper intValue] < [currentTileShapes tilesAcross])
			[tilesAcrossStepper setIntValue:MAX([currentTileShapes tilesAcross] - 10, [tilesAcrossStepper minValue])];
	}
    [currentTileShapes setTilesAcross:[tilesAcrossStepper intValue]];
    [tilesAcrossTextField setIntValue:[tilesAcrossStepper intValue]];
	
	[self updatePlugInDefaults];
}


- (IBAction)setTilesDown:(id)sender
{
		// Jump by 10 if the user had the option key down, by one otherwise.
	if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([tilesDownStepper intValue] > [currentTileShapes tilesDown])
			[tilesDownStepper setIntValue:MIN([currentTileShapes tilesDown] + 10, [tilesDownStepper maxValue])];
		else if ([tilesDownStepper intValue] < [currentTileShapes tilesDown])
			[tilesDownStepper setIntValue:MAX([currentTileShapes tilesDown] - 10, [tilesDownStepper minValue])];
	}
    [currentTileShapes setTilesDown:[tilesDownStepper intValue]];
    [tilesDownTextField setIntValue:[tilesDownStepper intValue]];
	
	[self updatePlugInDefaults];
}


@end
