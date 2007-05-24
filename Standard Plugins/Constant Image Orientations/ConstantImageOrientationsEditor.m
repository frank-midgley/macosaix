//
//  DirectoryImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "ConstantImageOrientationsEditor.h"
#import "ConstantImageOrientations.h"


@implementation MacOSaiXConstantImageOrientationsEditor


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
		[NSBundle loadNibNamed:@"Constant Image Orientations" owner:self];
	
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
	
	[angleSlider setFloatValue:[currentImageOrientations constantAngle]];
	[angleTextField setFloatValue:[currentImageOrientations constantAngle]];
}


- (IBAction)setConstantAngle:(id)sender
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
	
	[currentImageOrientations setConstantAngle:angle];
	[angleSlider setFloatValue:fmodf(angle + 360.0, 360.0)];
	[angleTextField setFloatValue:angle];
	
	[[self delegate] dataSource:currentImageOrientations settingsDidChange:NSLocalizedString(@"Change Constant Angle", @"")];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	[self setConstantAngle:angleTextField];
}


//- (BOOL)settingsAreValid
//{
//	return YES;
//}


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
