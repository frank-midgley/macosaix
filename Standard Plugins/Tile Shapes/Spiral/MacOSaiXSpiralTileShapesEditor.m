//
//  SpiralTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 8/16/2007.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSpiralTileShapesEditor.h"

#import "MacOSaiXSpiralTileShapes.h"
#import "NSString+MacOSaiX.h"


#define MIN_TIGHTNESS		0.0057
#define MAX_TIGHTNESS		0.1
#define MIN_ASPECT_RATIO	0.1
#define MAX_ASPECT_RATIO	10.0


@implementation MacOSaiXSpiralTileShapesEditor


+ (NSString *)name
{
	return NSLocalizedString(@"Spiral", @"");
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
		[NSBundle loadNibNamed:@"Spiral Tile Shapes" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(274.0, 147.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return spiralTightnessSlider;
}


- (void)updatePlugInDefaults
{
	NSMutableDictionary	*settings =[NSMutableDictionary dictionary];
	
	[settings setObject:[NSNumber numberWithFloat:[currentTileShapes spiralTightness]] forKey:@"Spiral Tightness"];
	[settings setObject:[NSNumber numberWithFloat:[currentTileShapes tileAspectRatio]] forKey:@"Tile Aspect Ratio"];
	[settings setObject:[NSNumber numberWithBool:[currentTileShapes imagesFollowSpiral]] forKey:@"Images Follow Spiral"];
	
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"Spiral Tile Shapes"];
}


- (void)editDataSource:(id<MacOSaiXTileShapes>)tileShapes
{
	[currentTileShapes autorelease];
	currentTileShapes = [tileShapes retain];
	
	[self refresh];
}


- (IBAction)setSpiralTightness:(id)sender
{
	float	previousValue = [currentTileShapes spiralTightness];
	
	[currentTileShapes setSpiralTightness:(1.0 - sqrtf([spiralTightnessSlider floatValue])) * (MAX_TIGHTNESS - MIN_TIGHTNESS) + MIN_TIGHTNESS];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"spiralTightness"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Spiral Tightness"];
}


- (void)setTileAspectRatio:(float)tileAspectRatio
{
		// Update the slider.
	float	mappedRatio = 0.0;
	if (tileAspectRatio < 1.0)
		mappedRatio = (tileAspectRatio - MIN_ASPECT_RATIO) / (1.0 - MIN_ASPECT_RATIO);
	else
		mappedRatio = (tileAspectRatio - 1.0) / (MAX_ASPECT_RATIO - 1.0) + 1.0;
	[tileAspectRatioSlider setFloatValue:mappedRatio];
	NSString	*toolTipFormat = NSLocalizedString(@"Aspect ratio: %0.2f", @"");
	[tileAspectRatioSlider setToolTip:[NSString stringWithFormat:toolTipFormat, tileAspectRatio]];
	
		// Update the pop-up.
	[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:tileAspectRatio]];
	
	float	previousValue = [currentTileShapes tileAspectRatio];
	
	if (tileAspectRatio != previousValue)
	{
		[currentTileShapes setTileAspectRatio:tileAspectRatio];
		
		[self updatePlugInDefaults];
		
		[[self delegate] dataSource:currentTileShapes 
					   didChangeKey:@"tileAspectRatio"
						  fromValue:[NSNumber numberWithFloat:previousValue] 
						 actionName:@"Change Tiles Size"];
	}
}


- (IBAction)setTileSize:(id)sender
{
	if (sender == tilesSizePopUp)
	{
		int		tag = [tilesSizePopUp selectedTag];
		
		if (tag == 0)
		{
			[otherSizeField setFloatValue:[currentTileShapes tileAspectRatio]];
			
			[NSApp beginSheet:otherSizePanel 
			   modalForWindow:[sender window] 
				modalDelegate:self 
			   didEndSelector:@selector(otherSizeSheetDidEnd:returnCode:contextInfo:) 
				  contextInfo:nil];
		}
		else
			[self setTileAspectRatio:(tag / 10) / fmodf(tag, 10.0)];
	}
	else
	{
		float	aspectRatio = [tileAspectRatioSlider floatValue];
		
			// Map from the slider's scale to the actual ratio.
		if (aspectRatio < 1.0)
			[self setTileAspectRatio:MIN_ASPECT_RATIO + (1.0 - MIN_ASPECT_RATIO) * aspectRatio];
		else if (aspectRatio > 1.0)
			[self setTileAspectRatio:1.0 + (MAX_ASPECT_RATIO - 1.0) * (aspectRatio - 1.0)];
	}
}


- (IBAction)setOtherSize:(id)sender
{
	[NSApp endSheet:otherSizePanel];
}


- (IBAction)cancelOtherSize:(id)sender
{
	[NSApp endSheet:otherSizePanel returnCode:NSRunAbortedResponse];
}


- (void)otherSizeSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[otherSizePanel orderOut:self];
	
	if (returnCode == NSRunStoppedResponse)
		[self setTileAspectRatio:[otherSizeField floatValue]];
}


- (IBAction)setImagesFollowSpiral:(id)sender
{
	BOOL	previousValue = [currentTileShapes imagesFollowSpiral];
	
	[currentTileShapes setImagesFollowSpiral:([imagesFollowSpiralMatrix selectedRow] == 0)];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"imagesFollowSpiral"
					  fromValue:[NSNumber numberWithBool:previousValue] 
					 actionName:@"Change Spiral Image Orientations"];
}


#pragma mark -


- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	// TBD: set spiral center point?
	return NO;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	// TBD: set spiral center point?
	return NO;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	// TBD: set spiral center point?
	return NO;
}


- (void)refresh
{
	[spiralTightnessSlider setFloatValue:powf(1.0 - ([currentTileShapes spiralTightness] - MIN_TIGHTNESS) / (MAX_TIGHTNESS - MIN_TIGHTNESS), 2.0)];
	
	[self setTileAspectRatio:[currentTileShapes tileAspectRatio]];
	
	[imagesFollowSpiralMatrix selectCellAtRow:([currentTileShapes imagesFollowSpiral] ? 0 : 1) column:0];
}


- (void)editingDidComplete
{
	[currentTileShapes release];
	
	delegate = nil;
}


- (void)dealloc
{
		// We are responsible for releasing any top-level objects in the nib.
	[editorView release];
	[otherSizePanel release];
	
	[super dealloc];
}


@end
