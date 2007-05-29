//
//  MacOSaiXBitmapExportEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapExportEditor.h"

#import "MacOSaiXBitmapExportSettings.h"


@implementation MacOSaiXBitmapExportEditor


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
		[NSBundle loadNibNamed:@"Bitmap Export" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(338.0, 94.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return formatMatrix;
}


- (void)editDataSource:(MacOSaiXBitmapExportSettings *)settings
{
	currentSettings = settings;
	
		// Populate the GUI
	if ([[currentSettings format] isEqualToString:@"JPEG"])
		[formatMatrix selectCellAtRow:0 column:0];
	else if ([[currentSettings format] isEqualToString:@"PNG"])
		[formatMatrix selectCellAtRow:1 column:0];
	else if ([[currentSettings format] isEqualToString:@"TIFF"])
		[formatMatrix selectCellAtRow:2 column:0];
	[widthField setFloatValue:[currentSettings width]];
	[heightField setFloatValue:[currentSettings height]];
	[unitsPopUp selectItemWithTag:[currentSettings units]];
	[resolutionPopUp selectItemWithTag:[currentSettings pixelsPerInch]];
}


- (IBAction)setFormat:(id)sender
{
	if ([formatMatrix selectedRow] == 0)
		[currentSettings setFormat:@"JPEG"];
	else if ([formatMatrix selectedRow] == 1)
		[currentSettings setFormat:@"PNG"];
	else if ([formatMatrix selectedRow] == 2)
		[currentSettings setFormat:@"TIFF"];
	
	[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Format"];
}


- (IBAction)setUnits:(id)sender
{
	// TBD: convert width & height?
	
	[currentSettings setUnits:[unitsPopUp selectedTag]];
	
	[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Units"];
}


- (IBAction)setResolution:(id)sender
{
	[currentSettings setPixelsPerInch:[resolutionPopUp selectedTag]];
	
	[[self delegate] dataSource:currentSettings settingsDidChange:@"Change Resolution"];
}


- (void)editingDidComplete
{
	[currentSettings setWidth:[widthField floatValue]];
	[currentSettings setHeight:[heightField floatValue]];

	currentSettings = nil;
}


@end
