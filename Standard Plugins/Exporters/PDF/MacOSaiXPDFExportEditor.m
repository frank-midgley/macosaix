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
	return NSMakeSize(254.0, 72.0);
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
	
	[widthField setFloatValue:[currentSettings width]];
	[heightField setFloatValue:[currentSettings height]];
	[unitsPopUp selectItemWithTag:[currentSettings units]];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	targetImageSize = [[currentSettings targetImage] size];
	float	aspectRatio = targetImageSize.width / targetImageSize.height;
	
	if ([notification object] == widthField)
	{
		float	newWidth = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newHeight = newWidth / aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setWidth:newHeight];
		[heightField setFloatValue:newHeight];
		[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Width"];
	}
	else if ([notification object] == heightField)
	{
		float	newHeight = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newWidth = newHeight * aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setHeight:newHeight];
		[widthField setFloatValue:newWidth];
		[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Height"];
	}
}


- (IBAction)setUnits:(id)sender
{
	MacOSaiXPDFUnits	previousUnits = [currentSettings units], 
						newUnits = [unitsPopUp selectedTag];
	
	[currentSettings setUnits:newUnits];
	
		// Convert the width and height to the new units if needed.
	if (previousUnits == inchUnits && newUnits == cmUnits)
	{
		[currentSettings setWidth:[currentSettings width] * 2.54];
		[currentSettings setHeight:[currentSettings height] * 2.54];
	}
	else if (previousUnits == cmUnits && newUnits == inchUnits)
	{
		[currentSettings setWidth:[currentSettings width] / 2.54];
		[currentSettings setHeight:[currentSettings height] / 2.54];
	}
	
	[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Units"];
}


- (void)editingDidComplete
{
	currentSettings = nil;
}


@end
