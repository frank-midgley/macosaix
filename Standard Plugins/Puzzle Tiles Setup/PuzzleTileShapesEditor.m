//
//  PuzzleTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "PuzzleTileShapesEditor.h"
#import "NSString+MacOSaiX.h"


enum { tilesSize1x1 = 1, tilesSize3x4, tilesSize4x3 };


@interface MacOSaiXPuzzleTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
- (void)setFixedSizeControlsBasedOnFreeformControls;
- (void)updatePreview:(NSTimer *)timer;
@end


@implementation MacOSaiXPuzzleTileShapesEditor


+ (NSString *)name
{
	return NSLocalizedString(@"Puzzle Pieces", @"");
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"PuzzleTilesSetup" owner:self];
	
	return editorView;
}


- (id)initWithDelegate:(id<MacOSaiXDataSourceEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXDataSourceEditorDelegate>)delegate
{
	return delegate;
}


- (NSSize)minimumSize
{
	return NSMakeSize(325.0, 255.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return tilesAcrossTextField;
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes tilesAcross]], @"Tiles Across", 
														[NSNumber numberWithInt:[currentTileShapes tilesDown]], @"Tiles Down", 
														[NSNumber numberWithFloat:[tabbedSidesSlider floatValue] * 100.0], @"Tabbed Sides Percentage", 
														[NSNumber numberWithFloat:[curvinessSlider floatValue] * 100.0], @"Curviness Percentage", 
														[NSNumber numberWithBool:([alignImagesMatrix selectedRow] == 1)], @"Align Images", 
														nil]
											  forKey:@"Puzzle Tile Shapes"];
}


- (void)editDataSource:(id<MacOSaiXTileShapes>)tileShapes
{
	[currentTileShapes autorelease];
	currentTileShapes = [tileShapes retain];
	
	targetImageSize = [[[self delegate] targetImage] size];
	
	minAspectRatio = (targetImageSize.width / [tilesAcrossSlider maxValue]) / 
					 (targetImageSize.height / [tilesDownSlider minValue]);
	maxAspectRatio = (targetImageSize.width / [tilesAcrossSlider minValue]) / 
					 (targetImageSize.height / [tilesDownSlider maxValue]);
	
		// Constrain the tiles across value to the stepper's range and update the model and view.
	int				tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
	[currentTileShapes setTilesAcross:tilesAcross];
	[tilesAcrossSlider setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	[tilesAcrossStepper setIntValue:tilesAcross];
	
		// Constrain the tiles down value to the stepper's range and update the model and view.
	int				tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
	[currentTileShapes setTilesDown:tilesDown];
	[tilesDownSlider setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
	[tilesDownStepper setIntValue:tilesDown];
	
	[self setFixedSizeControlsBasedOnFreeformControls];
	
	float			tabbedSidesRatio = MIN(MAX([currentTileShapes tabbedSidesRatio], [tabbedSidesSlider minValue]), [tabbedSidesSlider maxValue]);
	[currentTileShapes setTabbedSidesRatio:tabbedSidesRatio];
	[tabbedSidesSlider setFloatValue:tabbedSidesRatio];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", tabbedSidesRatio * 100.0]];
	
	float			curviness = MIN(MAX([currentTileShapes curviness], [curvinessSlider minValue]), [curvinessSlider maxValue]);
	[currentTileShapes setCurviness:curviness];
	[curvinessSlider setFloatValue:curviness];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", curviness * 100.0]];
	
//	[self updatePreview:nil];
//	previewTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
//													 target:self 
//												   selector:@selector(updatePreview:) 
//												   userInfo:nil 
//													repeats:YES] retain];
}


#pragma mark -
#pragma mark Number of Pieces


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
	
	[[self delegate] plugInSettingsDidChange:@"Change Tiles Across"];
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
	
	[[self delegate] plugInSettingsDidChange:@"Change Tiles Down"];
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
	
	[currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
	[currentTileShapes setTilesDown:[tilesDownSlider intValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] plugInSettingsDidChange:@"Change Tiles Size"];
}


- (IBAction)setTilesCount:(id)sender
{
	[self setFreeFormControlsBasedOnFixedSizeControls];
	
	[currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
	[currentTileShapes setTilesDown:[tilesDownSlider intValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] plugInSettingsDidChange:@"Change Number of Tiles"];
}


#pragma mark -
#pragma mark Options


- (IBAction)setTabbedSides:(id)sender
{
	[currentTileShapes setTabbedSidesRatio:[tabbedSidesSlider floatValue]];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([tabbedSidesSlider floatValue] * 100.0)]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] plugInSettingsDidChange:@"Change Frequency of Tabbed Sides"];
}


- (IBAction)setCurviness:(id)sender
{
	[currentTileShapes setCurviness:[curvinessSlider floatValue]];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([curvinessSlider floatValue] * 100.0)]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] plugInSettingsDidChange:@"Change Curviness of Tiles"];
}


- (IBAction)setImagesAligned:(id)sender
{
	[currentTileShapes setImagesAligned:[alignImagesMatrix selectedRow] == 1];
	
	[self updatePlugInDefaults];
}


//- (BOOL)settingsAreValid
//{
//	return YES;
//}


//- (int)tileCount
//{
//	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
//}


//- (void)updatePreview:(NSTimer *)timer
//{
//		// Pick a new random puzzle piece.
//	float		tileAspectRatio = (targetImageSize.width / [tilesAcrossSlider intValue]) / 
//								  (targetImageSize.height / [tilesDownSlider intValue]), 
//				tabbedSidesRatio = [currentTileShapes tabbedSidesRatio],
//				curviness = [currentTileShapes curviness];
//	
//	[previewShape release];
//	previewShape = [[MacOSaiXPuzzleTileShape alloc] initWithBounds:NSMakeRect(0.0, 0.0, 1.0, 1.0 / tileAspectRatio) 
//														topTabType:(random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1 
//													   leftTabType:(random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1 
//													  rightTabType:(random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1 
//													 bottomTabType:(random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1 
//											topLeftHorizontalCurve:(random() % 200 - 100) / 100.0 * curviness 
//											  topLeftVerticalCurve:(random() % 200 - 100) / 100.0 * curviness 
//										   topRightHorizontalCurve:(random() % 200 - 100) / 100.0 * curviness 
//											 topRightVerticalCurve:(random() % 200 - 100) / 100.0 * curviness 
//										 bottomLeftHorizontalCurve:(random() % 200 - 100) / 100.0 * curviness 
//										   bottomLeftVerticalCurve:(random() % 200 - 100) / 100.0 * curviness 
//										bottomRightHorizontalCurve:(random() % 200 - 100) / 100.0 * curviness 
//										  bottomRightVerticalCurve:(random() % 200 - 100) / 100.0 * curviness 
//														alignImage:([alignImagesMatrix selectedRow] == 1)];
//	
//		// Dummy event to let MacOSaiX know that the preview should be updated.
//	[[editorView window] sendEvent:nil];
//}


//- (id<MacOSaiXTileShape>)previewShape
//{
//	return	previewShape;
//}


- (void)editingDidComplete
{
//	[previewTimer invalidate];
//	[previewTimer release];
//	previewTimer = nil;

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
