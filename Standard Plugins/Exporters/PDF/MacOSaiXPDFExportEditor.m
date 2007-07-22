//
//  MacOSaiXPDFExportEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPDFExportEditor.h"

#import "MacOSaiXPDFExportSettings.h"


@implementation MacOSaiXPDFExportEditor


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
		[NSBundle loadNibNamed:@"PDF Export" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(260.0, 72.0);
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
	currentSettings = (MacOSaiXPDFExportSettings *)dataSource;
	
	[self refresh];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	targetImageSize = [[currentSettings targetImage] size];
	float	aspectRatio = targetImageSize.width / targetImageSize.height;
	
	if ([notification object] == widthField)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		float	newWidth = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newHeight = newWidth / aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setHeight:newHeight];
		[heightField setFloatValue:newHeight];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthHeightUnits" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Width", @"")];
	}
	else if ([notification object] == heightField)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		float	newHeight = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newWidth = newHeight * aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setHeight:newHeight];
		[widthField setFloatValue:newWidth];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthHeightUnits" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Height", @"")];
	}
}


- (IBAction)setUnits:(id)sender
{
	MacOSaiXPDFUnits	previousUnits = [currentSettings units], 
						newUnits = [unitsPopUp selectedTag];
	
	if (previousUnits != newUnits)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		
			// Convert the width and height to the new units.
		float	factor = (newUnits == cmUnits ? 2.54 : 1.0 / 2.54), 
				newWidth = [currentSettings width] * factor, 
				newHeight = [currentSettings height] * factor;
		[currentSettings setWidth:newWidth];
		[widthField setFloatValue:newWidth];
		[currentSettings setHeight:newHeight];
		[heightField setFloatValue:newHeight];
		
		[currentSettings setUnits:newUnits];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthHeightUnits" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Units", @"")];
	}
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
	[widthField setFloatValue:[currentSettings width]];
	[heightField setFloatValue:[currentSettings height]];
	[unitsPopUp selectItemWithTag:[currentSettings units]];
}


- (void)editingDidComplete
{
	currentSettings = nil;
}


@end
