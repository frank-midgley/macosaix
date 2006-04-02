//
//  PuzzleTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PuzzleTileShapesEditor.h"
#import "NSString+MacOSaiX.h"


enum { tilesSize1x1 = 1, tilesSize3x4, tilesSize4x3 };


@interface MacOSaiXPuzzleTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
- (void)setFixedSizeControlsBasedOnFreeformControls;
@end


@implementation MacOSaiXPuzzleTileShapesEditor


+ (NSString *)name
{
	return @"Puzzle Pieces";
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"PuzzleTilesSetup" owner:self];
	
	return editorView;
}


- (id)initWithDelegate:(id)delegate
{
	if (self = [super init])
		editorDelegate = delegate;
	
	return self;
}


- (NSSize)minimumSize
{
	return NSMakeSize(325.0, 255.0);
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
	
	[editorDelegate tileShapesWereEdited];
	
	previewTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
													 target:self 
												   selector:@selector(updatePreview:) 
												   userInfo:nil 
													repeats:YES] retain];
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
	if (originalImageSize.height * minX * aspectRatio / originalImageSize.width < minY)
		minX = originalImageSize.width * minY / aspectRatio / originalImageSize.height;
	if (originalImageSize.width * minY / aspectRatio / originalImageSize.height < minX)
		minY = minX * originalImageSize.height * aspectRatio / originalImageSize.width;
	if (originalImageSize.height * maxX * aspectRatio / originalImageSize.width > maxY)
		maxX = originalImageSize.width * maxY / aspectRatio / originalImageSize.height;
	if (originalImageSize.width * maxY / aspectRatio / originalImageSize.height > maxX)
		maxY = maxX * originalImageSize.height * aspectRatio / originalImageSize.width;
	
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
	float	tileAspectRatio = (originalImageSize.width / tilesAcross) / 
							  (originalImageSize.height / tilesDown);
	
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
	if (originalImageSize.height * minX * tileAspectRatio / originalImageSize.width < minY)
		minTileCount = minX * minX / tileAspectRatio;
	else
		minTileCount = minY * minY * tileAspectRatio;
	if (originalImageSize.height * maxX * tileAspectRatio / originalImageSize.width < maxY)
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
	
	[editorDelegate tileShapesWereEdited];
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
	
	[editorDelegate tileShapesWereEdited];
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
	
	[editorDelegate tileShapesWereEdited];
}


- (IBAction)setTilesCount:(id)sender
{
	[self setFreeFormControlsBasedOnFixedSizeControls];
	
	[currentTileShapes setTilesAcross:[tilesAcrossSlider intValue]];
	[currentTileShapes setTilesDown:[tilesDownSlider intValue]];
	
	[self updatePlugInDefaults];
	
	[editorDelegate tileShapesWereEdited];
}


#pragma mark -
#pragma mark Options


- (IBAction)setTabbedSides:(id)sender
{
	[currentTileShapes setTabbedSidesRatio:[tabbedSidesSlider floatValue]];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([tabbedSidesSlider floatValue] * 100.0)]];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


- (IBAction)setCurviness:(id)sender
{
	[currentTileShapes setCurviness:[curvinessSlider floatValue]];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([curvinessSlider floatValue] * 100.0)]];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


- (IBAction)setImagesAligned:(id)sender
{
	[currentTileShapes setImagesAligned:[alignImagesMatrix selectedRow] == 1];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


- (int)tileCount
{
	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
}


- (void)updatePreview:(NSTimer *)timer
{
		// Pick a new random puzzle piece.
	float	tabbedSidesRatio = [currentTileShapes tabbedSidesRatio],
			curviness = [currentTileShapes curviness];
	
	previewPiece.topTabType = (random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1;
	previewPiece.leftTabType = (random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1;
	previewPiece.rightTabType = (random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1;
	previewPiece.bottomTabType = (random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : (random() % 2) * 2 - 1;
	previewPiece.topLeftHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topLeftVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topRightHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topRightVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomLeftHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomLeftVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomRightHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomRightVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.alignImages = ([alignImagesMatrix selectedRow] == 1);
	
	[editorDelegate tileShapesWereEdited];
}


- (NSBezierPath *)previewPath
{
	float		tileAspectRatio = (originalImageSize.width / [tilesAcrossSlider intValue]) / 
								  (originalImageSize.height / [tilesDownSlider intValue]);
	return [MacOSaiXPuzzleTileShapes puzzlePathWithSize:NSMakeSize(1.0, 1.0 / tileAspectRatio) 
											 attributes:previewPiece];
}


- (void)editingComplete
{
	[previewTimer invalidate];
	[previewTimer release];
	previewTimer = nil;

	[currentTileShapes release];
}


- (void)dealloc
{
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
