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


- (id)initWithDelegate:(id<MacOSaiXDataSourceEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXDataSourceEditorDelegate>)delegate
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
	return NSMakeSize(237.0, 34.0);
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
		angle = -[angleSlider floatValue];
	else if (sender == angleTextField)
		angle = [angleTextField floatValue];
	
	angle = fmodf(angle + 360.0, 360.0);
	
	[currentImageOrientations setConstantAngle:angle];
	[angleSlider setFloatValue:fmodf(-angle + 360.0, 360.0)];
	[angleTextField setFloatValue:angle];
	
	[[self delegate] plugInSettingsDidChange:NSLocalizedString(@"Change Constant Angle", @"")];
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
