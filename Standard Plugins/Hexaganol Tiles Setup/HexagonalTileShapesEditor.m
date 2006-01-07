//
//  HexagonalTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HexagonalTileShapesEditor.h"
#import "NSString+MacOSaiX.h"


@interface MacOSaiXHexagonalTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
@end


@implementation MacOSaiXHexagonalTileShapesEditor


+ (NSString *)name
{
	return @"Hexagons";
}


- (NSView *)mainView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"HexagonalTileShapes" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(340.0, 175.0);
}


- (NSResponder *)firstResponder
{
	return tilesAcrossTextField;
}


- (id)initWithDelegate:(id)delegate
{
	if (self = [super init])
	{
		editorDelegate = delegate;
		
		originalImageSize = [[editorDelegate originalImage] size];
	}
	
	return self;
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
											  forKey:@"Hexagonal Tile Shapes"];
}


- (void)setCurrentTileShapes:(id<MacOSaiXTileShapes>)tileShapes
{
	[currentTileShapes autorelease];
	currentTileShapes = [tileShapes retain];
}


- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup
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
	
	NSDictionary	*lastUsedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Hexagonal Tile Shapes"];
	[restrictTileSizeCheckBox setState:[[lastUsedSettings objectForKey:@"Restrict Tile Size"] boolValue]];
	[restrictedXSizePopUpButton selectItemWithTitle:[lastUsedSettings objectForKey:@"Restrict Tile X Size"]];
	[restrictedYSizePopUpButton selectItemWithTitle:[lastUsedSettings objectForKey:@"Restrict Tile Y Size"]];
	
	if ([restrictTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
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
	
	[editorDelegate tileShapesWereEdited];
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
	
	[editorDelegate tileShapesWereEdited];
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
		[editorDelegate tileShapesWereEdited];
	
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
		[editorDelegate tileShapesWereEdited];
	
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


- (int)tileCount
{
	return [tilesAcrossTextField intValue] * [tilesDownTextField intValue] + [tilesDownTextField intValue] / 2;
}


- (NSBezierPath *)previewPath
{
	float			unitHeight = (originalImageSize.height / [tilesDownTextField intValue]) / 
								 (originalImageSize.width / [tilesAcrossTextField intValue]);
	NSBezierPath	*previewPath = [NSBezierPath bezierPath];
	
	[previewPath moveToPoint:NSMakePoint(1.0 / 3.0, 0.0)];
	[previewPath lineToPoint:NSMakePoint(1.0, 0.0)];
	[previewPath lineToPoint:NSMakePoint(4.0 / 3.0, unitHeight / 2.0)];
	[previewPath lineToPoint:NSMakePoint(1.0, unitHeight)];
	[previewPath lineToPoint:NSMakePoint(1.0 / 3.0, unitHeight)];
	[previewPath lineToPoint:NSMakePoint(0.0, unitHeight / 2.0)];
	[previewPath lineToPoint:NSMakePoint(1.0 / 3.0, 0.0)];
	
	return previewPath;
}


- (void)editingComplete
{
	[currentTileShapes release];
}


- (void)dealloc
{
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
