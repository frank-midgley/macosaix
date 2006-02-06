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


enum { tilesSizeOther, tilesSize1x1, tilesSize3x4, tilesSize4x3 };


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


- (NSSize)minimumSize
{
	return NSMakeSize(339.0, 90.0);
}


- (NSResponder *)firstResponder
{
	return tilesAcrossSlider;
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes tilesAcross]], @"Tiles Across", 
														[NSNumber numberWithInt:[currentTileShapes tilesDown]], @"Tiles Down", 
														[NSNumber numberWithInt:0], @"Last Used Tab", 
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
	
//	NSDictionary	*lastUsedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
//	[preserveTileSizeCheckBox setState:[[lastUsedSettings objectForKey:@"Freeform or Fixed Size"] boolValue]];
//	
//	if ([preserveTileSizeCheckBox state] == NSOnState)
//		[self setTilesDownBasedOnTilesAcross];
	
	[editorDelegate tileShapesWereEdited];
}


- (float)aspectRatio
{
	float	aspectRatio = [tilesSizeSlider floatValue];
	
	if (aspectRatio < 1.0)
		aspectRatio = minAspectRatio + (1.0 - minAspectRatio) * aspectRatio;
	else if (aspectRatio > 1.0)
		aspectRatio = 1.0 + (maxAspectRatio - 1.0) * (aspectRatio - 1.0);
		
	return aspectRatio;
}


- (void)setFreeFormControlsBasedOnFixedSizeControls
{
	float	aspectRatio = [self aspectRatio], 
			tileCount = [tilesCountSlider floatValue];
	
	int		minX = [tilesAcrossSlider minValue], 
			minY = [tilesDownSlider minValue], 
			maxX = [tilesAcrossSlider maxValue], 
			maxY = [tilesDownSlider maxValue];
	if (originalImageSize.height * minX / aspectRatio / originalImageSize.width < minY)
		minX = originalImageSize.width * minY * aspectRatio / originalImageSize.height;
	if (originalImageSize.width * minY * aspectRatio / originalImageSize.height < minX)
		minY = minX * originalImageSize.height / aspectRatio / originalImageSize.width;
	if (originalImageSize.height * maxX / aspectRatio / originalImageSize.width > maxY)
		maxX = originalImageSize.width * maxY * aspectRatio / originalImageSize.height;
	if (originalImageSize.width * maxY * aspectRatio / originalImageSize.height > maxX)
		maxY = maxX * originalImageSize.height / aspectRatio / originalImageSize.width;
	
	int		tilesAcross = minX + (maxX - minX) * tileCount, 
			tilesDown = minY + (maxY - minY) * tileCount;
	
	[tilesAcrossSlider setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	[tilesDownSlider setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
}


- (void)setFixedSizeControlsBasedOnFreeformControls
{
	float	tileAspectRatio = (originalImageSize.width / [tilesAcrossSlider intValue]) / 
	(originalImageSize.height / [tilesDownSlider intValue]);
	
	[tilesSizeTextField setStringValue:[NSString stringWithAspectRatio:tileAspectRatio]];
	
	if (tileAspectRatio < 1.0)
		tileAspectRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
	else if (tileAspectRatio > 1.0)
		tileAspectRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
	[tilesSizeSlider setFloatValue:tileAspectRatio];
	
//	int		tilesAcross = [tilesAcrossSlider intValue], 
//			tilesDown = [tilesDownSlider intValue];
//	float	targetAspectRatio = [self aspectRatio];
//	
//	tilesDown = originalImageSize.height * (float)tilesAcross / originalImageSize.width * targetAspectRatio;
//	
//	if (fabsf((originalImageSize.height / tilesDown) / (originalImageSize.width / tilesAcross) - targetAspectRatio) > 
//		fabsf((originalImageSize.height / (tilesDown + 1)) / (originalImageSize.width / tilesAcross) - targetAspectRatio))
//		tilesDown++;
//	
//	if (tilesDown >= [tilesDownSlider minValue] && tilesDown <= [tilesDownSlider maxValue])
//	{
//		[currentTileShapes setTilesDown:tilesDown];
//		[tilesDownSlider setIntValue:tilesDown];
//		[tilesDownTextField setIntValue:tilesDown];
//		[self updatePlugInDefaults];
//		[self updateTileCountAndSizeFields];
//	}
//	else if (tilesAcross > [tilesAcrossSlider minValue])
//	{
//		[tilesAcrossSlider setIntValue:tilesAcross - 1];
//		[tilesAcrossTextField setIntValue:tilesAcross - 1];
//		[self setTilesDownBasedOnTilesAcross];
//	}
}


- (IBAction)setTilesAcross:(id)sender
{
    [currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
    [tilesAcrossTextField setIntValue:[tilesAcrossSlider intValue]];
	
	[self setFixedSizeControlsBasedOnFreeformControls];
	
	[self updatePlugInDefaults];
	
	[editorDelegate tileShapesWereEdited];
}


- (IBAction)setTilesDown:(id)sender
{
    [currentTileShapes setTilesDown:[tilesDownSlider intValue]];
    [tilesDownTextField setIntValue:[tilesDownSlider intValue]];
	
	[self setFixedSizeControlsBasedOnFreeformControls];
	
	[self updatePlugInDefaults];
	
	[editorDelegate tileShapesWereEdited];
}


- (IBAction)setTilesSize:(id)sender
{
	int	tilesSize = [tilesSizePopUp selectedTag];
	
	if (tilesSize == tilesSizeOther)
	{
		if ([tilesSizeSlider respondsToSelector:@selector(setHidden:)])
		{
			[tilesSizeSlider setHidden:NO];
			[tilesSizeTextField setHidden:NO];
		}
		[tilesSizeSlider setEnabled:YES];
		[tilesSizeTextField setEnabled:YES];
		[tilesSizeTextField setStringValue:[NSString stringWithAspectRatio:[self aspectRatio]]];
	}
	else
	{
		if ([tilesSizeSlider respondsToSelector:@selector(setHidden:)])
		{
			[tilesSizeSlider setHidden:YES];
			[tilesSizeTextField setHidden:YES];
		}
		[tilesSizeSlider setEnabled:NO];
		[tilesSizeTextField setEnabled:NO];
		[tilesSizeTextField setStringValue:@""];
		
			// Use a preset ratio.
		float	tileAspectRatio = 1.0;
		if (tilesSize == tilesSize3x4)
			tileAspectRatio = 4.0 / 3.0;
		else if (tilesSize == tilesSize4x3)
			tileAspectRatio = 3.0 / 4.0;
		
			// Map the ratio to the slider position.
		if (tileAspectRatio < 1.0)
			tileAspectRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
		else
			tileAspectRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
		[tilesSizeSlider setFloatValue:tileAspectRatio];
		
		[self setFreeFormControlsBasedOnFixedSizeControls];
		
		[currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
		[currentTileShapes setTilesDown:[tilesDownSlider intValue]];
		
		[self updatePlugInDefaults];
		
		[editorDelegate tileShapesWereEdited];
	}
}


- (IBAction)setOtherTilesSize:(id)sender
{
	[self setFreeFormControlsBasedOnFixedSizeControls];
	
	[currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
	[currentTileShapes setTilesDown:[tilesDownSlider intValue]];
	
	[self updatePlugInDefaults];
	
	[editorDelegate tileShapesWereEdited];
}


- (int)tileCount
{
	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
}


- (NSBezierPath *)previewPath
{
	return [NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, 100.0, 100.0 / [self aspectRatio])];
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
