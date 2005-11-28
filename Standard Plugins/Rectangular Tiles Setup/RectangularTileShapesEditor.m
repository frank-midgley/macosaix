//
//  RectangularTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RectangularTileShapesEditor.h"
#import "NSString+MacOSaiX.h"


@interface MacOSaiXRectangularTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
@end


@implementation MacOSaiXRectangularTileShapesEditor


+ (NSString *)name
{
	return @"Rectangles";
}


- (id)initWithDelegate:(id)delegate
{
	if (self = [super init])
	{
		editorDelegate = delegate;
	}
	
	return self;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"RectangularTileShapes" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(252.0, 88.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return tilesAcrossSlider;
}


- (void)updateTileCountAndSizeFields
{
	if ([preserveTileSizeCheckBox state] == NSOffState)
	{
		float	tileAspectRatio = (originalImageSize.width / [tilesAcrossSlider intValue]) / 
								  (originalImageSize.height / [tilesDownSlider intValue]);

		[tileSizeTextField setStringValue:[NSString stringWithAspectRatio:tileAspectRatio]];
		
		if (tileAspectRatio < 1.0)
			tileAspectRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
		else if (tileAspectRatio > 1.0)
			tileAspectRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
		[tileSizeSlider setFloatValue:tileAspectRatio];
	}
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes tilesAcross]], @"Tiles Across", 
														[NSNumber numberWithInt:[currentTileShapes tilesDown]], @"Tiles Down", 
														[NSNumber numberWithBool:([preserveTileSizeCheckBox state] == NSOnState)], 
															@"Preserve Tile Size", 
														nil]
											  forKey:@"Rectangular Tile Shapes"];
}


- (void)setCurrentTileShapes:(id<MacOSaiXTileShapes>)tileShapes
{
	[currentTileShapes autorelease];
	currentTileShapes = [tileShapes retain];
}


- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup
{
	[self setCurrentTileShapes:tilesSetup];
	
	originalImageSize = [[editorDelegate originalImage] size];
	
	minAspectRatio = (originalImageSize.width / [tilesAcrossSlider maxValue]) / 
					 (originalImageSize.height / [tilesDownSlider minValue]);
	maxAspectRatio = (originalImageSize.width / [tilesAcrossSlider minValue]) / 
					 (originalImageSize.height / [tilesDownSlider maxValue]);
	
		// Constrain the tiles across value to the stepper's range and update the model and view.
	int	tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
	[currentTileShapes setTilesAcross:tilesAcross];
	[tilesAcrossSlider setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	
		// Constrain the tiles down value to the stepper's range and update the model and view.
	int	tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
	[currentTileShapes setTilesDown:tilesDown];
	[tilesDownSlider setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
	
	NSDictionary	*lastUsedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
	[preserveTileSizeCheckBox setState:[[lastUsedSettings objectForKey:@"Preserve Tile Size"] boolValue]];
	
	if ([preserveTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updateTileCountAndSizeFields];
	[editorDelegate tileShapesWereEdited];
}


- (float)aspectRatio
{
	float	aspectRatio = [tileSizeSlider floatValue];
	
	if (aspectRatio < 1.0)
		aspectRatio = minAspectRatio + (1.0 - minAspectRatio) * aspectRatio;
	else if (aspectRatio > 1.0)
		aspectRatio = 1.0 + (maxAspectRatio - 1.0) * (aspectRatio - 1.0);
		
	return aspectRatio;
}


- (void)setTilesAcrossBasedOnTilesDown
{
	int		tilesAcross = [tilesAcrossSlider intValue], 
			tilesDown = [tilesDownSlider intValue];
	float	targetAspectRatio = [self aspectRatio];
	
	tilesAcross = originalImageSize.width * (float)tilesDown / originalImageSize.height * targetAspectRatio;
	
	if (fabsf((originalImageSize.height / tilesDown) / (originalImageSize.width / tilesAcross) - targetAspectRatio) > 
		fabsf((originalImageSize.height / tilesDown) / (originalImageSize.width / (tilesAcross + 1)) - targetAspectRatio))
		tilesAcross++;
	
	if (tilesAcross >= [tilesAcrossSlider minValue] && tilesAcross <= [tilesAcrossSlider maxValue])
	{
		[currentTileShapes setTilesAcross:tilesAcross];
		[tilesAcrossSlider setIntValue:tilesAcross];
		[tilesAcrossTextField setIntValue:tilesAcross];
		[self updatePlugInDefaults];
		[self updateTileCountAndSizeFields];
	}
	else if (tilesDown > [tilesDownSlider minValue])
	{
		[tilesDownSlider setIntValue:tilesDown - 1];
		[tilesDownTextField setIntValue:tilesDown - 1];
		[self setTilesAcrossBasedOnTilesDown];
	}
}


- (void)setTilesDownBasedOnTilesAcross
{
	int		tilesAcross = [tilesAcrossSlider intValue], 
			tilesDown = [tilesDownSlider intValue];
	float	targetAspectRatio = [self aspectRatio];
	
	tilesDown = originalImageSize.height * (float)tilesAcross / originalImageSize.width * targetAspectRatio;
	
	if (fabsf((originalImageSize.height / tilesDown) / (originalImageSize.width / tilesAcross) - targetAspectRatio) > 
		fabsf((originalImageSize.height / (tilesDown + 1)) / (originalImageSize.width / tilesAcross) - targetAspectRatio))
		tilesDown++;
	
	if (tilesDown >= [tilesDownSlider minValue] && tilesDown <= [tilesDownSlider maxValue])
	{
		[currentTileShapes setTilesDown:tilesDown];
		[tilesDownSlider setIntValue:tilesDown];
		[tilesDownTextField setIntValue:tilesDown];
		[self updatePlugInDefaults];
		[self updateTileCountAndSizeFields];
	}
	else if (tilesAcross > [tilesAcrossSlider minValue])
	{
		[tilesAcrossSlider setIntValue:tilesAcross - 1];
		[tilesAcrossTextField setIntValue:tilesAcross - 1];
		[self setTilesDownBasedOnTilesAcross];
	}
	
}


- (IBAction)setTilesAcross:(id)sender
{
    [currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
    [tilesAcrossTextField setIntValue:[tilesAcrossSlider intValue]];
	
	if ([preserveTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	else
		[self updateTileCountAndSizeFields];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


- (IBAction)setTilesDown:(id)sender
{
    [currentTileShapes setTilesDown:[tilesDownSlider intValue]];
    [tilesDownTextField setIntValue:[tilesDownSlider intValue]];
	
	if ([preserveTileSizeCheckBox state] == NSOnState)
		[self setTilesAcrossBasedOnTilesDown];
	else
		[self updateTileCountAndSizeFields];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


- (IBAction)setTileSizePreserved:(id)sender
{
	if ([preserveTileSizeCheckBox state] == NSOnState)
	{
		[self setTilesDownBasedOnTilesAcross];
		[tileSizeSlider setEnabled:NO];
	}
	else
		[tileSizeSlider setEnabled:YES];
	
	[self updatePlugInDefaults];
}


- (IBAction)setTilesSize:(id)sender
{
	[self setTilesDownBasedOnTilesAcross];
	
	[editorDelegate tileShapesWereEdited];
		
	[self updatePlugInDefaults];
}


- (int)tileCount
{
	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
}


- (NSBezierPath *)previewPath
{
	return [NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, 100.0, 100.0 / [self aspectRatio])];
}


- (void)dealloc
{
	[currentTileShapes release];
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
