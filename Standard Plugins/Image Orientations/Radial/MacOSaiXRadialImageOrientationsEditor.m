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
	return NSMakeSize(211.0, 98.0);
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
	
	[self refresh];
}


- (void)setPreset:(MacOSaiXRadialImageOrientations *)preset
{
	if (preset)
	{
			// Use preset orientations.
		[currentImageOrientations setName:[preset name]];
		[currentImageOrientations setFocusPoint:[preset focusPoint]];
		[currentImageOrientations setOffsetAngle:[preset offsetAngle]];
		
		if ([customControlsBox respondsToSelector:@selector(setHidden:)])
			[customControlsBox setHidden:YES];
		else
		{
			[angleSlider setEnabled:NO];
			[angleTextField setEnabled:NO];
		}
	}
	else
	{
			// Allow the user to set custom orientations.
		[currentImageOrientations setName:nil];
		
		if ([customControlsBox respondsToSelector:@selector(setHidden:)])
			[customControlsBox setHidden:NO];
		else
		{
			[angleSlider setEnabled:YES];
			[angleTextField setEnabled:YES];
		}
	}
	
	[angleSlider setFloatValue:[currentImageOrientations offsetAngle]];
	[angleTextField setFloatValue:[currentImageOrientations offsetAngle]];
}


- (IBAction)setPresetOrientations:(id)sender
{
	NSDictionary	*previousValue = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSValue valueWithPoint:[currentImageOrientations focusPoint]], @"Focus Point", 
											[NSNumber numberWithFloat:[currentImageOrientations offsetAngle]], @"Offset Angle", 
											[currentImageOrientations name], @"Name", 
											nil];
	
	[self setPreset:[[presetsPopUp selectedItem] representedObject]];
	
	[[self delegate] dataSource:currentImageOrientations 
				   didChangeKey:@"nameFocusPointAngle" 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Change Radial Type", @"")];
}


- (IBAction)setOffsetAngle:(id)sender
{
	float	previousValue = [currentImageOrientations offsetAngle], 
			angle = 0;
	
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
	
	[[self delegate] dataSource:currentImageOrientations 
				   didChangeKey:@"offsetAngle" 
					  fromValue:[NSNumber numberWithFloat:previousValue] 
					 actionName:NSLocalizedString(@"Change Offset Angle", @"")];
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
		
		if (!NSEqualPoints(focusPoint, [currentImageOrientations focusPoint]))
		{
			NSPoint	previousValue = [currentImageOrientations focusPoint];
			
			[currentImageOrientations setFocusPoint:focusPoint];
			
			[[self delegate] dataSource:currentImageOrientations 
						   didChangeKey:@"focusPoint" 
							  fromValue:[NSValue valueWithPoint:previousValue] 
							 actionName:NSLocalizedString(@"Change Radial Focus Point", @"")];
		}
		
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
		
		if (!NSEqualPoints(focusPoint, [currentImageOrientations focusPoint]))
		{
			NSPoint	previousValue = [currentImageOrientations focusPoint];
			
			[currentImageOrientations setFocusPoint:focusPoint];
			
			[[self delegate] dataSource:currentImageOrientations 
						   didChangeKey:@"focusPoint" 
							  fromValue:[NSValue valueWithPoint:previousValue] 
							 actionName:NSLocalizedString(@"Change Radial Focus Point", @"")];
		}
		
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
		
		if (!NSEqualPoints(focusPoint, [currentImageOrientations focusPoint]))
		{
			NSPoint	previousValue = [currentImageOrientations focusPoint];
			
			[currentImageOrientations setFocusPoint:focusPoint];
			
			[[self delegate] dataSource:currentImageOrientations 
						   didChangeKey:@"focusPoint" 
							  fromValue:[NSValue valueWithPoint:previousValue] 
							 actionName:NSLocalizedString(@"Change Radial Focus Point", @"")];
		}
		
		handledEvent = YES;
	}
	
	return handledEvent;
}


- (void)refresh
{
	while ([presetsPopUp numberOfItems] > 1)
		[presetsPopUp removeItemAtIndex:0];
	
	NSEnumerator					*presetsEnumerator = [[MacOSaiXRadialImageOrientations presetOrientations] reverseObjectEnumerator];
	MacOSaiXRadialImageOrientations	*currentPreset = nil, 
									*preset = nil;
	NSMenuItem						*selectedItem = [presetsPopUp itemAtIndex:0];
	while (preset = [presetsEnumerator nextObject])
	{
		NSMenuItem	*presetItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString([preset name], @"") 
															  action:@selector(setPresetOrientations:) 
													   keyEquivalent:@""] autorelease];
		[presetItem setTarget:self];
		[presetItem setRepresentedObject:preset];
		[[presetsPopUp menu] insertItem:presetItem atIndex:0];
		
		if ([[currentImageOrientations name] isEqualToString:[preset name]])
		{
			selectedItem = presetItem;
			currentPreset = preset;
		}
	}
	[presetsPopUp selectItem:selectedItem];
	
	[self setPreset:currentPreset];
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
