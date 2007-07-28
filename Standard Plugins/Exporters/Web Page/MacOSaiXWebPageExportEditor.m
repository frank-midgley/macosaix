//
//  MacOSaiXWebPageExportEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWebPageExportEditor.h"

#import "MacOSaiXWebPageExportSettings.h"


@implementation MacOSaiXWebPageExportEditor


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
		[NSBundle loadNibNamed:@"Web Page" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(342.0, 109.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return widthField;
}


- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource
{
	currentSettings = (MacOSaiXWebPageExportSettings *)dataSource;
	
	[self refresh];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == widthField)
	{
		int		previousValue = [currentSettings width], 
				newWidth = [widthField intValue];
		
		[currentSettings setWidth:newWidth];
		
		[self refresh];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"width" 
						  fromValue:[NSNumber numberWithInt:previousValue] 
						 actionName:NSLocalizedString(@"Change Width", @"")];
	}
	else if ([notification object] == heightField)
	{
		int		previousValue = [currentSettings height], 
				newHeight = [heightField intValue];
		
		[currentSettings setHeight:newHeight];
		
		[self refresh];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"height" 
						  fromValue:[NSNumber numberWithInt:previousValue] 
						 actionName:NSLocalizedString(@"Change Height", @"")];
	}
}


- (IBAction)setIncludeTargetImage:(id)sender
{
	BOOL	previousValue = [currentSettings includeTargetImage];
	
	[currentSettings setIncludeTargetImage:([includeTargetImageButton state] == NSOnState)];
	
	[[self delegate] dataSource:currentSettings 
				   didChangeKey:@"includeTargetImage" 
					  fromValue:[NSNumber numberWithBool:previousValue] 
					 actionName:NSLocalizedString(@"Include Target Image in Web Page", @"")];
}


- (IBAction)setIncludeTilePopUps:(id)sender
{
	BOOL	previousValue = [currentSettings includeTilePopUps];
	
	[currentSettings setIncludeTilePopUps:([includeTilePopUpsButton state] == NSOnState)];
	
	[[self delegate] dataSource:currentSettings 
				   didChangeKey:@"includeTilePopUps" 
					  fromValue:[NSNumber numberWithBool:previousValue] 
					 actionName:NSLocalizedString(@"Include Tile Pop Ups in Web Page", @"")];
}


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
	[widthField setIntValue:[currentSettings width]];
	[heightField setIntValue:[currentSettings height]];
	
	[includeTargetImageButton setState:([currentSettings includeTargetImage] ? NSOnState : NSOffState)];
	[includeTilePopUpsButton setState:([currentSettings includeTilePopUps] ? NSOnState : NSOffState)];
}


- (void)editingDidComplete
{
	[currentSettings setWidth:[widthField intValue]];
	[currentSettings setHeight:[heightField intValue]];

	currentSettings = nil;
}


@end
