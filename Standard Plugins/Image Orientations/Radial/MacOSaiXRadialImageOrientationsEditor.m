//
//  MacOSaiXRadialImageOrientationsEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/13/07.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXRadialImageOrientationsEditor.h"
#import "MacOSaiXRadialImageOrientations.h"


@implementation MacOSaiXRadialImageOrientationsEditor


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
		[NSBundle loadNibNamed:@"Radial Image Orientations" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(282.0, 86.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return angleSlider;
}


- (void)editDataSource:(id<MacOSaiXImageOrientations>)imageOrientations
{
	[currentImageOrientations autorelease];
	currentImageOrientations = [imageOrientations retain];
	
	NSEnumerator					*presetsEnumerator = [[MacOSaiXRadialImageOrientations presetOrientations] reverseObjectEnumerator];
	MacOSaiXRadialImageOrientations	*preset = nil;
	NSMenuItem						*selectedItem = [presetsPopUp itemAtIndex:0];
	while (preset = [presetsEnumerator nextObject])
	{
		NSMenuItem	*presetItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString([preset name], @"") 
															  action:@selector(setPresetOrientations:) 
													   keyEquivalent:@""] autorelease];
		[presetItem setTarget:self];
		[presetItem setRepresentedObject:preset];
		[[presetsPopUp menu] insertItem:presetItem atIndex:0];
		
		if ([[(MacOSaiXRadialImageOrientations	*)imageOrientations name] isEqualToString:[preset name]])
			selectedItem = presetItem;
	}
	[presetsPopUp selectItem:selectedItem];
	[self setPresetOrientations:selectedItem];
	
	[angleSlider setFloatValue:[currentImageOrientations offsetAngle]];
	[angleTextField setFloatValue:[currentImageOrientations offsetAngle]];
}


- (IBAction)setPresetOrientations:(id)sender
{
	MacOSaiXRadialImageOrientations	*preset = [[presetsPopUp selectedItem] representedObject];
	
	if (preset)
	{
			// Use preset orientations.
		[currentImageOrientations setName:[preset name]];
		[currentImageOrientations setFocusPoint:[preset focusPoint]];
		[currentImageOrientations setOffsetAngle:[preset offsetAngle]];
		
		[angleSlider setEnabled:NO];
		[angleTextField setEnabled:NO];
	}
	else
	{
			// Allow the user to set custom orientations.
		[currentImageOrientations setName:nil];
		
		[angleSlider setEnabled:YES];
		[angleTextField setEnabled:YES];
	}
	
	[angleSlider setFloatValue:[currentImageOrientations offsetAngle]];
	[angleTextField setFloatValue:[currentImageOrientations offsetAngle]];
	
	[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Radial Type", @"")];
}


- (IBAction)setOffsetAngle:(id)sender
{
	float	angle = 0;
	
	if (sender == angleSlider)
	{
		angle = [angleSlider floatValue];
		if (angle > 180.0)
			angle -= 360.0;
	}
	else if (sender == angleTextField)
	{
		angle = [angleTextField floatValue];
		angle = MIN(MAX(angle, -180.0), 180.0);
	}
	
	[currentImageOrientations setOffsetAngle:angle];
	[angleSlider setFloatValue:fmodf(angle + 360.0, 360.0)];
	[angleTextField setFloatValue:angle];
	
	[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Offset Angle", @"")];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	[self setOffsetAngle:angleTextField];
}


- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	BOOL	handledEvent = NO;
	
	if (![currentImageOrientations name])
	{
		NSPoint	focusPoint = [event locationInWindow];
		NSSize	targetImageSize = [[[self delegate] targetImage] size];
		
		focusPoint.x /= targetImageSize.width;
		focusPoint.y /= targetImageSize.height;
		
		[currentImageOrientations setFocusPoint:focusPoint];
		
		[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Radial Focus Point", @"")];
		
		handledEvent = YES;
	}
	
	return handledEvent;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	BOOL	handledEvent = NO;
	
	if (![currentImageOrientations name])
	{
		NSPoint	focusPoint = [event locationInWindow];
		NSSize	targetImageSize = [[[self delegate] targetImage] size];
		
		focusPoint.x /= targetImageSize.width;
		focusPoint.y /= targetImageSize.height;
		
		[currentImageOrientations setFocusPoint:focusPoint];
		
		[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Radial Focus Point", @"")];
		
		handledEvent = YES;
	}
	
	return handledEvent;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	BOOL	handledEvent = NO;
	
	if (![currentImageOrientations name])
	{
		NSPoint	focusPoint = [event locationInWindow];
		NSSize	targetImageSize = [[[self delegate] targetImage] size];
		
		focusPoint.x /= targetImageSize.width;
		focusPoint.y /= targetImageSize.height;
		
		[currentImageOrientations setFocusPoint:focusPoint];
		
		[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Radial Focus Point", @"")];
		
		handledEvent = YES;
	}
	
	return handledEvent;
}


- (void)editingDidComplete
{
	while ([presetsPopUp numberOfItems] > 1)
		[presetsPopUp removeItemAtIndex:0];
	
	[currentImageOrientations release];
	currentImageOrientations = nil;
	
	delegate = nil;
}


- (void)dealloc
{
	[super dealloc];
}


@end
