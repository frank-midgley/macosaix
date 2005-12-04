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


@interface MacOSaiXPuzzleTileShapesEditor (PrivateMethods)
- (void)setTilesAcrossBasedOnTilesDown;
- (void)setTilesDownBasedOnTilesAcross;
@end


@implementation MacOSaiXPuzzleTileShapesEditor


+ (NSString *)name
{
	return @"Puzzle Pieces";
}


- (NSView *)editorView
{
	if (!editorView)
	{
		[NSBundle loadNibNamed:@"PuzzleTilesSetup" owner:self];
		[tileSizeSlider setMinValue:1.0/9.0];
		[tileSizeSlider setMaxValue:9.0/1.0];
	}
	
	return editorView;
}


- (id)initWithDelegate:(id)delegate
{
	if (self = [super init])
	{
		editorDelegate = delegate;
		
		originalImageSize = [[editorDelegate originalImage] size];
		
		previewTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
														 target:self 
													   selector:@selector(updatePreview:) 
													   userInfo:nil 
														repeats:YES] retain];
	}
	
	return self;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(340.0, 148.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return tilesAcrossTextField;
}


- (void)updateTileCountAndSizeFields
{
	if ([preserveTileSizeCheckBox state] == NSOffState)
	{
		float	tileAspectRatio = (originalImageSize.width / [tilesAcrossSlider intValue]) / 
								  (originalImageSize.height / [tilesDownSlider intValue]);
		[tileSizeTextField setStringValue:[NSString stringWithAspectRatio:tileAspectRatio]];
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
	
		// Constrain the tiles across value to the stepper's range and update the model and view.
	int				tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
	[currentTileShapes setTilesAcross:tilesAcross];
	[tilesAcrossSlider setIntValue:tilesAcross];
	[tilesAcrossTextField setIntValue:tilesAcross];
	
		// Constrain the tiles down value to the stepper's range and update the model and view.
	int				tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
	[currentTileShapes setTilesDown:tilesDown];
	[tilesDownSlider setIntValue:tilesDown];
	[tilesDownTextField setIntValue:tilesDown];
	
	float			tabbedSidesRatio = MIN(MAX([currentTileShapes tabbedSidesRatio], [tabbedSidesSlider minValue]), [tabbedSidesSlider maxValue]);
	[currentTileShapes setTabbedSidesRatio:tabbedSidesRatio];
	[tabbedSidesSlider setFloatValue:tabbedSidesRatio];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%d%%", tabbedSidesRatio * 100.0]];
	
	float			curviness = MIN(MAX([currentTileShapes curviness], [curvinessSlider minValue]), [curvinessSlider maxValue]);
	[currentTileShapes setCurviness:curviness];
	[curvinessSlider setFloatValue:curviness];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%d%%", curviness * 100.0]];
	
	NSDictionary	*lastUsedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Puzzle Tile Shapes"];
	[preserveTileSizeCheckBox setState:[[lastUsedSettings objectForKey:@"Preserve Tile Size"] boolValue]];
	
	if ([preserveTileSizeCheckBox state] == NSOnState)
		[self setTilesDownBasedOnTilesAcross];
	
	[self updateTileCountAndSizeFields];
	[editorDelegate tileShapesWereEdited];
}


- (void)setTilesAcrossBasedOnTilesDown
{
	int		tilesAcross = [tilesAcrossSlider intValue], 
	tilesDown = [tilesDownSlider intValue];
	float	targetAspectRatio = [tileSizeSlider floatValue];
	
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
	float	targetAspectRatio = [tileSizeSlider floatValue];
	
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
		[tileSizeSlider setEnabled:YES];
	}
	else
		[tileSizeSlider setEnabled:NO];
	
	[self updatePlugInDefaults];
}


- (IBAction)setTilesSize:(id)sender
{
	[self setTilesDownBasedOnTilesAcross];
	
	[editorDelegate tileShapesWereEdited];
	
	[self updatePlugInDefaults];
}


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


- (int)tileCount
{
	return [tilesAcrossSlider intValue] * [tilesDownSlider intValue];
}


- (void)updatePreview:(NSTimer *)timer
{
		// Pick a new random puzzle piece.
	int		x = random() % [tilesAcrossSlider intValue],
			y = random() % [tilesDownSlider intValue];
	float	tabbedSidesRatio = [currentTileShapes tabbedSidesRatio],
			curviness = [currentTileShapes curviness];
	
	previewPiece.topTabType = (y == [tilesDownSlider intValue] - 1 || random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : random() % 2 + 1;
	previewPiece.leftTabType = (x == 0 || random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : random() % 2 + 1;
	previewPiece.rightTabType = (x == [tilesAcrossSlider intValue] - 1 || random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : random() % 2 + 1;
	previewPiece.bottomTabType = (y == 0 || random() % 100 >= tabbedSidesRatio * 100.0) ? noTab : random() % 2 + 1;
	previewPiece.topLeftHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topLeftVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topRightHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.topRightVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomLeftHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomLeftVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomRightHorizontalCurve = (random() % 200 - 100) / 100.0 * curviness;
	previewPiece.bottomRightVerticalCurve = (random() % 200 - 100) / 100.0 * curviness;
	
	[editorDelegate tileShapesWereEdited];
}


- (NSBezierPath *)previewPath
{
	float		tileAspectRatio = (originalImageSize.width / [tilesAcrossSlider intValue]) / 
								  (originalImageSize.height / [tilesDownSlider intValue]);
	return [currentTileShapes puzzlePathWithSize:NSMakeSize(1.0, 1.0 / tileAspectRatio) 
									  attributes:previewPiece];
}


- (void)dealloc
{
	[previewTimer invalidate];
	[previewTimer release];
	
	[currentTileShapes release];
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
