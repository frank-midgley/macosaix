//
//  RectangularTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RectangularTileShapesEditor.h"


@interface MacOSaiXRectangularTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
@end


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


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(340.0, 175.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return tilesAcrossTextField;
}


- (void)updateTileCountAndSizeFields
{
	[tileCountTextField setIntValue:[tilesAcrossStepper intValue] * [tilesDownStepper intValue]];
	
	int			xInt,
				yInt;
	float		tileAspectRatio = (originalImageSize.width / [tilesAcrossStepper intValue]) / 
								  (originalImageSize.height / [tilesDownStepper intValue]),
				minDiff = INFINITY;
	NSString	*ratioString = @"";
	
	for (xInt = 1; xInt < 10; xInt++)
	{
		yInt = (xInt / tileAspectRatio);
		if (fabsf(tileAspectRatio - (float)xInt / (float)yInt) > 
			fabsf(tileAspectRatio - (float)xInt / (float)(yInt + 1)))
			yInt++;
		
		float	curDiff = fabsf(tileAspectRatio - (float)xInt / (float)yInt);
		
		if (curDiff < minDiff)
		{
			minDiff = curDiff;
			ratioString = [NSString stringWithFormat:@"%dx%d", xInt, yInt];
		}
	}
	
	[tileSizeTextField setStringValue:ratioString];
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes tilesAcross]], @"Tiles Across", 
														[NSNumber numberWithInt:[currentTileShapes tilesDown]], @"Tiles Down", 
														[NSNumber numberWithBool:([restrictTileSizeCheckBox state] == NSOnState)], 
															@"Restrict Tile Size", 
														[restrictedXSizePopUpButton titleOfSelectedItem], @"Restrict Tile X Size", 
														[restrictedYSizePopUpButton titleOfSelectedItem], @"Restrict Tile Y Size", 
														nil]
											  forKey:@"Rectangular Tile Shapes"];
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
	
	originalImageSize = [originalImage size];
	
	NSDictionary	*lastUsedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
	[restrictTileSizeCheckBox setState:[[lastUsedSettings objectForKey:@"Restrict Tile Size"] boolValue]];
	[restrictedXSizePopUpButton selectItemWithTitle:[lastUsedSettings objectForKey:@"Restrict Tile X Size"]];
	[restrictedYSizePopUpButton selectItemWithTitle:[lastUsedSettings objectForKey:@"Restrict Tile Y Size"]];
	
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updateTileCountAndSizeFields];
}


- (void)setTilesAcrossBasedOnTilesDown
{
	int		tilesAcross = [tilesAcrossStepper intValue], 
			tilesDown = [tilesDownStepper intValue];
	float	targetAspectRatio = (float)[[restrictedXSizePopUpButton titleOfSelectedItem] intValue] / 
								(float)[[restrictedYSizePopUpButton titleOfSelectedItem] intValue];
	
	tilesAcross = originalImageSize.width * (float)tilesDown / originalImageSize.height / targetAspectRatio;
	
	if (fabsf((originalImageSize.width / tilesAcross) / (originalImageSize.height / tilesDown) - targetAspectRatio) > 
		fabsf((originalImageSize.width / (tilesAcross + 1)) / (originalImageSize.height / tilesDown) - targetAspectRatio))
		tilesAcross++;
	
	if (tilesAcross >= [tilesAcrossStepper minValue] && tilesAcross <= [tilesAcrossStepper maxValue])
	{
		[currentTileShapes setTilesAcross:tilesAcross];
		[tilesAcrossStepper setIntValue:tilesAcross];
		[tilesAcrossTextField setIntValue:tilesAcross];
		[self updatePlugInDefaults];
	}
	else
		NSBeep();
	
	[self updateTileCountAndSizeFields];
}


- (void)setTilesDownBasedOnTilesAcross
{
	int		tilesAcross = [tilesAcrossStepper intValue], 
			tilesDown = [tilesDownStepper intValue];
	float	targetAspectRatio = (float)[[restrictedXSizePopUpButton titleOfSelectedItem] intValue] / 
								(float)[[restrictedYSizePopUpButton titleOfSelectedItem] intValue];
	
	tilesDown = originalImageSize.height * tilesAcross * targetAspectRatio / originalImageSize.width;
	
	if (fabsf((originalImageSize.width / tilesAcross) / (originalImageSize.height / tilesDown) - targetAspectRatio) > 
		fabsf((originalImageSize.width / tilesAcross) / (originalImageSize.height / (tilesDown + 1)) - targetAspectRatio))
		tilesDown++;
	
	if (tilesDown >= [tilesDownStepper minValue] && tilesDown <= [tilesDownStepper maxValue])
	{
		[currentTileShapes setTilesDown:tilesDown];
		[tilesDownStepper setIntValue:tilesDown];
		[tilesDownTextField setIntValue:tilesDown];
		[self updatePlugInDefaults];
	}
	else
		NSBeep();
	
	[self updateTileCountAndSizeFields];
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
	
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	else
		[self updateTileCountAndSizeFields];
	
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
	
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesAcrossBasedOnTilesDown];
	else
		[self updateTileCountAndSizeFields];
	
	[self updatePlugInDefaults];
}


- (IBAction)restrictTileSize:(id)sender
{
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updatePlugInDefaults];
}


- (IBAction)setRestrictedXSize:(id)sender
{
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updatePlugInDefaults];
}


- (IBAction)setRestrictedYSize:(id)sender
{
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updatePlugInDefaults];
}


- (void)dealloc
{
	[currentTileShapes release];
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
