//
//  RectangularTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "RectangularTileShapesEditor.h"

#import "RectangularTileShapes.h"
#import "NSString+MacOSaiX.h"


enum { tilesSize1x1 = 1, tilesSize3x4, tilesSize4x3 };


@interface MacOSaiXRectangularTileShapesEditor (PrivateMethods)
- (void)setFixedSizeControlsBasedOnFreeformControls;
- (void)setFreeFormControlsBasedOnFixedSizeControls;
@end


@implementation MacOSaiXRectangularTileShapesEditor


+ (NSString *)name
{
	return NSLocalizedString(@"Rectangles", @"");
}


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"RectangularTileShapes" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(300.0, 132.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return tilesAcrossSlider;
}


- (void)updatePlugInDefaults
{
	NSMutableDictionary	*settings =[NSMutableDictionary dictionary];
	
	if ([currentTileShapes isFreeForm])
	{
		[settings setObject:@"Free-form" forKey:@"Sizing"];
		[settings setObject:[NSNumber numberWithInt:[currentTileShapes tilesAcross]] forKey:@"Tiles Across"];
		[settings setObject:[NSNumber numberWithInt:[currentTileShapes tilesDown]] forKey:@"Tiles Across"];
	}
	else
	{
		[settings setObject:@"Fixed Size" forKey:@"Sizing"];
		[settings setObject:[NSNumber numberWithFloat:[currentTileShapes tileAspectRatio]] forKey:@"Tile Aspect Ratio"];
		[settings setObject:[NSNumber numberWithFloat:[currentTileShapes tileCount]] forKey:@"Tile Count"];
	}

	[[NSUserDefaults standardUserDefaults] setObject:settings
											  forKey:@"Rectangular Tile Shapes"];
}


- (void)editDataSource:(id<MacOSaiXTileShapes>)tilesSetup
{
	[currentTileShapes autorelease];
	currentTileShapes = [tilesSetup retain];
	
	targetImageSize = [[[self delegate] targetImage] size];
	
	minAspectRatio = (targetImageSize.width / [tilesAcrossSlider maxValue]) / 
					 (targetImageSize.height / [tilesDownSlider minValue]);
	maxAspectRatio = (targetImageSize.width / [tilesAcrossSlider minValue]) / 
					 (targetImageSize.height / [tilesDownSlider maxValue]);
	
	if ([currentTileShapes isFreeForm])
	{
		[sizingTabView selectTabViewItemAtIndex:0];
		
			// Constrain the tiles across value to the stepper's range and update the model and view.
		int	tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
		[currentTileShapes setTilesAcross:tilesAcross];
		[tilesAcrossSlider setIntValue:tilesAcross];
		[tilesAcrossTextField setIntValue:tilesAcross];
		[tilesAcrossStepper setIntValue:tilesAcross];
		
			// Constrain the tiles down value to the stepper's range and update the model and view.
		int	tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
		[currentTileShapes setTilesDown:tilesDown];
		[tilesDownSlider setIntValue:tilesDown];
		[tilesDownTextField setIntValue:tilesDown];
		[tilesDownStepper setIntValue:tilesDown];
		
		[self setFixedSizeControlsBasedOnFreeformControls];
	}
	else
	{
		[sizingTabView selectTabViewItemAtIndex:1];
		
		float	aspectRatio = [currentTileShapes tileAspectRatio];
		[tilesSizeSlider setFloatValue:aspectRatio];
		[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:aspectRatio]];
		
		[tilesCountSlider setFloatValue:[currentTileShapes tileCount]];
		
		[self setFreeFormControlsBasedOnFixedSizeControls];
	}
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
			targetTileCount = [tilesCountSlider floatValue];
	
	int		minX = [tilesAcrossSlider minValue], 
			minY = [tilesDownSlider minValue], 
			maxX = [tilesAcrossSlider maxValue], 
			maxY = [tilesDownSlider maxValue];
	if (targetImageSize.height * minX * aspectRatio / targetImageSize.width < minY)
		minX = targetImageSize.width * minY / aspectRatio / targetImageSize.height;
	if (targetImageSize.width * minY / aspectRatio / targetImageSize.height < minX)
		minY = minX * targetImageSize.height * aspectRatio / targetImageSize.width;
	if (targetImageSize.height * maxX * aspectRatio / targetImageSize.width > maxY)
		maxX = targetImageSize.width * maxY / aspectRatio / targetImageSize.height;
	if (targetImageSize.width * maxY / aspectRatio / targetImageSize.height > maxX)
		maxY = maxX * targetImageSize.height * aspectRatio / targetImageSize.width;
	
	int		tilesAcross = minX + (maxX - minX) * targetTileCount, 
			tilesDown = minY + (maxY - minY) * targetTileCount;
	
	[tilesAcrossSlider setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	[tilesAcrossStepper setIntValue:tilesAcross];
	[tilesDownSlider setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
	[tilesDownStepper setIntValue:tilesDown];
}


- (void)setFixedSizeControlsBasedOnFreeformControls
{
	int		tilesAcross = [tilesAcrossSlider intValue], 
			tilesDown = [tilesDownSlider intValue];
	float	tileAspectRatio = (targetImageSize.width / tilesAcross) / 
							  (targetImageSize.height / tilesDown);
	
		// Update the tile size slider and pop-up.
	if (tileAspectRatio < 1.0)
		tileAspectRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
	else if (tileAspectRatio > 1.0)
		tileAspectRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
	[tilesSizeSlider setFloatValue:tileAspectRatio];
	
	[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:[self aspectRatio]]];
	
		// Update the tile count slider.
	int		minX = [tilesAcrossSlider minValue], 
			minY = [tilesDownSlider minValue], 
			maxX = [tilesAcrossSlider maxValue], 
			maxY = [tilesDownSlider maxValue], 
			minTileCount = 0,
			maxTileCount = 0;
	if (targetImageSize.height * minX * tileAspectRatio / targetImageSize.width < minY)
		minTileCount = minX * minX / tileAspectRatio;
	else
		minTileCount = minY * minY * tileAspectRatio;
	if (targetImageSize.height * maxX * tileAspectRatio / targetImageSize.width < maxY)
		maxTileCount = maxX * maxX / tileAspectRatio;
	else
		maxTileCount = maxY * maxY * tileAspectRatio;
	[tilesCountSlider setFloatValue:(float)(tilesAcross * tilesDown - minTileCount) / (maxTileCount - minTileCount)];
}


- (IBAction)setTilesAcross:(id)sender
{
    [currentTileShapes setTilesAcross:[sender intValue]];
    [tilesAcrossTextField setIntValue:[sender intValue]];
	if (sender == tilesAcrossSlider)
		[tilesAcrossStepper setIntValue:[sender intValue]];
	else
		[tilesAcrossSlider setIntValue:[sender intValue]];
		
	[self setFixedSizeControlsBasedOnFreeformControls];
	
	[self updatePlugInDefaults];
	
	[delegate plugInSettingsDidChange:NSLocalizedString(@"Change Tiles Across", @"")];
}


- (IBAction)setTilesDown:(id)sender
{
    [currentTileShapes setTilesDown:[sender intValue]];
    [tilesDownTextField setIntValue:[sender intValue]];
	if (sender == tilesDownSlider)
		[tilesDownStepper setIntValue:[sender intValue]];
	else
		[tilesDownSlider setIntValue:[sender intValue]];
	
	[self setFixedSizeControlsBasedOnFreeformControls];
	
	[self updatePlugInDefaults];
	
	[delegate plugInSettingsDidChange:NSLocalizedString(@"Change Tiles Down", @"")];
}


- (IBAction)setTilesSize:(id)sender
{
	if (sender == tilesSizePopUp)
	{
		float	tileAspectRatio = 1.0;
		if ([tilesSizePopUp selectedTag] == tilesSize3x4)
			tileAspectRatio = 3.0 / 4.0;
		else if ([tilesSizePopUp selectedTag] == tilesSize4x3)
			tileAspectRatio = 4.0 / 3.0;
		
			// Map the ratio to the slider position.
		if (tileAspectRatio < 1.0)
			tileAspectRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
		else
			tileAspectRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
		[tilesSizeSlider setFloatValue:tileAspectRatio];
	}
	
	[self setFreeFormControlsBasedOnFixedSizeControls];
	[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:[self aspectRatio]]];
	
	[currentTileShapes setTileAspectRatio:[self aspectRatio]];
	
	[self updatePlugInDefaults];
	
	[delegate plugInSettingsDidChange:NSLocalizedString(@"Change Tiles Size", @"")];
}


- (IBAction)setTilesCount:(id)sender
{
	[self setFreeFormControlsBasedOnFixedSizeControls];
	
	[currentTileShapes setTileCount:[tilesCountSlider floatValue]];
	
	[self updatePlugInDefaults];
	
	[delegate plugInSettingsDidChange:NSLocalizedString(@"Change Number of Tiles", @"")];
}


//- (BOOL)settingsAreValid
//{
//	return YES;
//}


//- (int)tileCount
//{
//	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
//}


//- (id<MacOSaiXTileShape>)previewShape
//{
//	NSBezierPath	*previewPath = [NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, 100.0, 100.0 / [self aspectRatio])];
//	
//	return [MacOSaiXRectangularTileShape tileShapeWithOutline:previewPath];
//}


- (void)editingDidComplete
{
	[currentTileShapes release];
	targetImageSize = NSMakeSize(1.0, 1.0);
	
	delegate = nil;
}


- (void)dealloc
{
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
