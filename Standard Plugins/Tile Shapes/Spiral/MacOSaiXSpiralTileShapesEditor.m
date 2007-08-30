//
//  SpiralTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 8/16/2007.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSpiralTileShapesEditor.h"

#import "MacOSaiXSpiralTileShapes.h"


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
	return NSMakeSize(248.0, 94.0);
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
	
	[currentTileShapes setSpiralTightness:[spiralTightnessSlider floatValue]];
	
	[self updatePlugInDefaults];
	
	[[self delegate] dataSource:currentTileShapes 
				   didChangeKey:@"spiralTightness"
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:@"Change Spiral Tightness"];
}


- (void)setTileAspectRatio:(float)tileAspectRatio
{
// TODO
//	float	previousValue = [currentTileShapes tileAspectRatio];
//		
//	if (tileAspectRatio != previousValue)
//	{
//			// Update the slider.
//		float	mappedRatio = 0.0;
//		if (tileAspectRatio < 1.0)
//			mappedRatio = (tileAspectRatio - minAspectRatio) / (1.0 - minAspectRatio);
//		else
//			mappedRatio = (tileAspectRatio - 1.0) / (maxAspectRatio - 1.0) + 1.0;
//		[tileAspectRatioSlider setFloatValue:mappedRatio];
//		NSString	*toolTipFormat = NSLocalizedString(@"Aspect ratio: %0.2f", @"");
//		[tileAspectRatioSlider setToolTip:[NSString stringWithFormat:toolTipFormat, tileAspectRatio]];
//		
//			// Update the pop-up.
//		[[tilesSizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:tileAspectRatio]];
//		
//		[currentTileShapes setTileAspectRatio:tileAspectRatio];
//		
//		[self updatePlugInDefaults];
//		
//		[[self delegate] dataSource:currentTileShapes 
//					   didChangeKey:@"tileAspectRatio"
//						  fromValue:[NSNumber numberWithFloat:previousValue] 
//						 actionName:@"Change Tiles Size"];
//	}
}


- (IBAction)setTileSize:(id)sender
{
// TODO
//	if (sender == tilesSizePopUp)
//	{
//		int		tag = [tilesSizePopUp selectedTag];
//		
//		if (tag == 0)
//		{
//			[otherSizeField setFloatValue:[currentTileShapes tileAspectRatio]];
//			
//			[NSApp beginSheet:otherSizePanel 
//			   modalForWindow:[sender window] 
//				modalDelegate:self 
//			   didEndSelector:@selector(otherSizeSheetDidEnd:returnCode:contextInfo:) 
//				  contextInfo:nil];
//		}
//		else
//			[self setTileAspectRatio:(tag / 10) / fmodf(tag, 10.0)];
//	}
//	else
//	{
//		float	aspectRatio = [tileAspectRatioSlider floatValue];
//		
//			// Map from the slider's scale to the actual ratio.
//		if (aspectRatio < 1.0)
//			[self setTileAspectRatio:minAspectRatio + (1.0 - minAspectRatio) * aspectRatio];
//		else if (aspectRatio > 1.0)
//			[self setTileAspectRatio:1.0 + (maxAspectRatio - 1.0) * (aspectRatio - 1.0)];
//	}
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
	[spiralTightnessSlider setFloatValue:[currentTileShapes spiralTightness]];
	[tileAspectRatioSlider setFloatValue:[currentTileShapes tileAspectRatio]];
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
