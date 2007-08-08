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


- (NSSize)minimumSize
{
	return NSMakeSize(285.0, 181.0);
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
	
	[self refresh];
}


#pragma mark -
#pragma mark Number of Pieces


- (IBAction)setTilesSizeType:(id)sender
{
	if ([tilesSizeMatrix selectedRow] == 0)
	{
		int	tilesAcross, 
			tilesDown;
		
		if ([currentTileShapes isFixedSize])
		{
				// Calculate the freefrom values from the fixed values and the size of the target image.
			float	aspectRatio = [currentTileShapes tileAspectRatio], 
					targetTileCount = [currentTileShapes tileCountFraction];
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
			
			tilesAcross = minX + (maxX - minX) * targetTileCount, 
			tilesDown = minY + (maxY - minY) * targetTileCount;
		}
		else
		{
			tilesAcross = [currentTileShapes tilesAcross];
			tilesDown = [currentTileShapes tilesDown];
		}
		
		[tilesAcrossSlider setIntValue:tilesAcross];
		[tilesAcrossTextField setIntValue:tilesAcross];
		[tilesAcrossStepper setIntValue:tilesAcross];
		[tilesDownSlider setIntValue:tilesDown];
		[tilesDownTextField setIntValue:tilesDown];
		[tilesDownStepper setIntValue:tilesDown];
		
		[tilesSizeTabView selectTabViewItemAtIndex:0];
	}
	else
	{
		float	aspectRatio, 
				tilesCountFraction;
		
		if ([currentTileShapes isFixedSize])
		{
			aspectRatio = [currentTileShapes tileAspectRatio];
			tilesCountFraction = [currentTileShapes tileCountFraction];
		}
		else
		{
				// Calculate the fixed values from the freeform values and the size of the target image.
			int		tilesAcross = [currentTileShapes tilesAcross], 
					tilesDown = [currentTileShapes tilesDown];
			
			aspectRatio = (targetImageSize.width / tilesAcross) / 
						  (targetImageSize.height / tilesDown);
			
				// Update the tile count slider.
			int		minX = [tilesAcrossSlider minValue], 
					minY = [tilesDownSlider minValue], 
					maxX = [tilesAcrossSlider maxValue], 
					maxY = [tilesDownSlider maxValue], 
					minTileCount = 0,
					maxTileCount = 0;
			if (targetImageSize.height * minX * aspectRatio / targetImageSize.width < minY)
				minTileCount = minX * minX / aspectRatio;
			else
				minTileCount = minY * minY * aspectRatio;
			if (targetImageSize.height * maxX * aspectRatio / targetImageSize.width < maxY)
				maxTileCount = maxX * maxX / aspectRatio;
			else
				maxTileCount = maxY * maxY * aspectRatio;
			
			tilesCountFraction = (tilesAcross * tilesDown - minTileCount) / (maxTileCount - minTileCount);
		}
		
		[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:aspectRatio]];
		
		if (aspectRatio < 1.0)
			aspectRatio = (aspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
		else if (aspectRatio > 1.0)
			aspectRatio = (aspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
		[tilesSizeSlider setFloatValue:aspectRatio];
		
		[tilesCountSlider setFloatValue:tilesCountFraction];
		
		[tilesSizeTabView selectTabViewItemAtIndex:1];
	}
}


- (IBAction)setTilesAcross:(id)sender
{
	int		previousValue = [currentTileShapes tilesAcross];
	
		// Jump by 10 instead of 1 if the option key is down when the stepper is clicked.
	if (sender == tilesAcrossStepper && ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([currentTileShapes tilesAcross] < [tilesAcrossStepper intValue])
			[tilesAcrossStepper setIntValue:MIN([currentTileShapes tilesAcross] + 10, [tilesAcrossStepper maxValue])];
		else
			[tilesAcrossStepper setIntValue:MAX([currentTileShapes tilesAcross] - 10, [tilesAcrossStepper minValue])];
	}
	
	[currentTileShapes setTilesAcross:[sender intValue]];
    [tilesAcrossTextField setIntValue:[sender intValue]];
	if (sender == tilesAcrossSlider)
		[tilesAcrossStepper setIntValue:[sender intValue]];
	else
		[tilesAcrossSlider setIntValue:[sender intValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tilesAcross"
					  fromValue:[NSNumber numberWithInt:previousValue] 
					 actionName:@"Change Tiles Across"];
}


- (IBAction)setTilesDown:(id)sender
{
	int		previousValue = [currentTileShapes tilesDown];
	
		// Jump by 10 instead of 1 if the option key is down when the stepper is clicked.
	if (sender == tilesDownStepper && ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0)
	{
		if ([currentTileShapes tilesDown] < [tilesDownStepper intValue])
			[tilesDownStepper setIntValue:MIN([currentTileShapes tilesDown] + 10, [tilesDownStepper maxValue])];
		else
			[tilesDownStepper setIntValue:MAX([currentTileShapes tilesDown] - 10, [tilesDownStepper minValue])];
	}
	
    [currentTileShapes setTilesDown:[sender intValue]];
    [tilesDownTextField setIntValue:[sender intValue]];
	if (sender == tilesDownSlider)
		[tilesDownStepper setIntValue:[sender intValue]];
	else
		[tilesDownSlider setIntValue:[sender intValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tilesDown"
					  fromValue:[NSNumber numberWithInt:previousValue] 
					 actionName:@"Change Tiles Down"];
}


- (IBAction)setTilesSize:(id)sender
{
	float	tileAspectRatio, 
			previousValue = [currentTileShapes tileAspectRatio];
	
	if (sender == tilesSizePopUp)
	{
		if ([tilesSizePopUp selectedTag] == tilesSize3x4)
			tileAspectRatio = 3.0 / 4.0;
		else if ([tilesSizePopUp selectedTag] == tilesSize4x3)
			tileAspectRatio = 4.0 / 3.0;
		else
			tileAspectRatio = 1.0;
		
			// Map the ratio to the slider position.
		float	mappedRatio = 0.0;
		if (tileAspectRatio < 1.0)
			mappedRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
		else
			mappedRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
		[tilesSizeSlider setFloatValue:mappedRatio];
	}
	else
	{
		tileAspectRatio = [tilesSizeSlider floatValue];
		
			// Map from the slider's scale to the actual ratio.
		if (tileAspectRatio < 1.0)
			tileAspectRatio = minAspectRatio + (1.0 - minAspectRatio) * tileAspectRatio;
		else if (tileAspectRatio > 1.0)
			tileAspectRatio = 1.0 + (maxAspectRatio - 1.0) * (tileAspectRatio - 1.0);
	}
	
	[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:tileAspectRatio]];
	
	[currentTileShapes setTileAspectRatio:tileAspectRatio];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tileAspectRatio"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Tiles Size"];
}


- (IBAction)setTilesCount:(id)sender
{
	float	previousValue = [currentTileShapes tileCountFraction];
	
	[currentTileShapes setTileCountFraction:[tilesCountSlider floatValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tileCountFraction"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Number of Tiles"];
}


#pragma mark -
#pragma mark Options


- (IBAction)setTabbedSides:(id)sender
{
	float	previousValue = [currentTileShapes tabbedSidesRatio];
	
	[currentTileShapes setTabbedSidesRatio:[tabbedSidesSlider floatValue]];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([tabbedSidesSlider floatValue] * 100.0)]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tabbedSidesRatio"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Frequency of Tabbed Sides"];
}


- (IBAction)setCurviness:(id)sender
{
	float	previousValue = [currentTileShapes curviness];
	
	[currentTileShapes setCurviness:[curvinessSlider floatValue]];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%d%%", (int)([curvinessSlider floatValue] * 100.0)]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"curviness"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Curviness of Tiles"];
}


- (IBAction)setImagesAligned:(id)sender
{
	BOOL	previousValue = [currentTileShapes imagesAligned];
	
	[currentTileShapes setImagesAligned:[alignImagesMatrix selectedRow] == 1];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"imagesAligned"
					  fromValue:[NSNumber numberWithBool:previousValue] 
					 actionName:@"Change Images Aligned"];
}


#pragma mark -
	
	
- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	return NO;
}


- (void)refresh
{
	targetImageSize = [[[self delegate] targetImage] size];
	
		// Determine the min and max aspect ratio based on the limits on the tiles across and down and the size of the target image.
	minAspectRatio = (targetImageSize.width / [tilesAcrossSlider maxValue]) / (targetImageSize.height / [tilesDownSlider minValue]);
	maxAspectRatio = (targetImageSize.width / [tilesAcrossSlider minValue]) / (targetImageSize.height / [tilesDownSlider maxValue]);
	
	if ([currentTileShapes isFixedSize])
	{
			// Constrain the tile aspect ratio and update the model and view.
		float	aspectRatio = MIN(MAX([currentTileShapes tileAspectRatio], minAspectRatio), maxAspectRatio);
		
		[currentTileShapes setTileAspectRatio:aspectRatio];
		
		[tilesSizeMatrix selectCellAtRow:1 column:0];
	}
	else
	{
			// Constrain the tiles across value to the stepper's range and update the model and view.
		int	tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
		[currentTileShapes setTilesAcross:tilesAcross];
		
			// Constrain the tiles down value to the stepper's range and update the model and view.
		int	tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
		[currentTileShapes setTilesDown:tilesDown];
		
		[tilesSizeMatrix selectCellAtRow:0 column:0];
	}
	
		// Populate the "Piece Count" tab.
	[self setTilesSizeType:self];
	
	float	tabbedSidesRatio = MIN(MAX([currentTileShapes tabbedSidesRatio], [tabbedSidesSlider minValue]), [tabbedSidesSlider maxValue]);
	[currentTileShapes setTabbedSidesRatio:tabbedSidesRatio];
	[tabbedSidesSlider setFloatValue:tabbedSidesRatio];
	[tabbedSidesTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", tabbedSidesRatio * 100.0]];
	
	float	curviness = MIN(MAX([currentTileShapes curviness], [curvinessSlider minValue]), [curvinessSlider maxValue]);
	[currentTileShapes setCurviness:curviness];
	[curvinessSlider setFloatValue:curviness];
	[curvinessTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", curviness * 100.0]];
}


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
