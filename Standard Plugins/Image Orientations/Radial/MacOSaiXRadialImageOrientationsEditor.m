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
	return NSMakeSize(196.0, 54.0);
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
	
	[angleSlider setFloatValue:[currentImageOrientations offsetAngle]];
	[angleTextField setFloatValue:[currentImageOrientations offsetAngle]];
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


- (void)editingDidComplete
{
	[currentImageOrientations release];
	currentImageOrientations = nil;
	
	delegate = nil;
}


- (void)dealloc
{
	[super dealloc];
}


@end
