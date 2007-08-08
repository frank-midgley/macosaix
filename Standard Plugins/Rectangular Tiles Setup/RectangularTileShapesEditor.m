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
	return NSMakeSize(259.0, 136.0);
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
		[settings setObject:[NSNumber numberWithInt:[currentTileShapes tilesDown]] forKey:@"Tiles Down"];
	}
	else
	{
		[settings setObject:@"Fixed Size" forKey:@"Sizing"];
		[settings setObject:[NSNumber numberWithFloat:[currentTileShapes tileAspectRatio]] forKey:@"Tile Aspect Ratio"];
		[settings setObject:[NSNumber numberWithFloat:[currentTileShapes tileCount]] forKey:@"Tile Count"];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"Rectangular Tile Shapes"];
}


- (void)editDataSource:(id<MacOSaiXTileShapes>)tilesSetup
{
	[currentTileShapes autorelease];
	currentTileShapes = [tilesSetup retain];
	
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
		
		if ([currentTileShapes isFreeForm])
		{
			tilesAcross = [currentTileShapes tilesAcross];
			tilesDown = [currentTileShapes tilesDown];
		}
		else
		{
				// Calculate the freefrom values from the fixed values and the size of the target image.
			float	aspectRatio = [currentTileShapes tileAspectRatio], 
					targetTileCount = [currentTileShapes tileCount];
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
		
		if ([currentTileShapes isFreeForm])
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
		else
		{
			aspectRatio = [currentTileShapes tileAspectRatio];
			tilesCountFraction = [currentTileShapes tileCount];
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
	float	previousValue = [currentTileShapes tileCount];
	
	[currentTileShapes setTileCount:[tilesCountSlider floatValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"tileCount"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Number of Tiles"];
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
	
	if ([currentTileShapes isFreeForm])
	{
			// Constrain the tiles across value to the stepper's range and update the model and view.
		int	tilesAcross = MIN(MAX([currentTileShapes tilesAcross], [tilesAcrossSlider minValue]), [tilesAcrossSlider maxValue]);
		[currentTileShapes setTilesAcross:tilesAcross];
		
			// Constrain the tiles down value to the stepper's range and update the model and view.
		int	tilesDown = MIN(MAX([currentTileShapes tilesDown], [tilesDownSlider minValue]), [tilesDownSlider maxValue]);
		[currentTileShapes setTilesDown:tilesDown];
		
		[tilesSizeMatrix selectCellAtRow:0 column:0];
	}
	else
	{
			// Constrain the tile aspect ratio and update the model and view.
		float	aspectRatio = MIN(MAX([currentTileShapes tileAspectRatio], minAspectRatio), maxAspectRatio);
		
		[currentTileShapes setTileAspectRatio:aspectRatio];
		
		[tilesSizeMatrix selectCellAtRow:1 column:0];
	}
	
		// Populate the "Piece Count" tab.
	[self setTilesSizeType:self];
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
