//
//  GlyphImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSourceController.h"


@implementation MacOSaiXGlyphImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Glyph Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(358.0, 266.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return fontsTableView;
}


- (void)awakeFromNib
{
	NSButtonCell	*checkboxCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
	[checkboxCell setButtonType:NSSwitchButton];
	[checkboxCell setTarget:self];
	[[[fontsTableView tableColumns] objectAtIndex:0] setDataCell:checkboxCell];
	[[[colorsTableView tableColumns] objectAtIndex:0] setDataCell:checkboxCell];
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	availableFontNames = [[[[NSFontManager sharedFontManager] availableFonts] 
								sortedArrayUsingSelector:@selector(compare:)] retain];
	
	sampleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
												   target:self 
												 selector:@selector(updateSample:) 
												 userInfo:nil 
												  repeats:YES];
	
	currentImageSource = (MacOSaiXGlyphImageSource *)imageSource;
}


- (void)updateSample:(NSTimer *)timer
{
	[currentImageSource reset];
	[sampleImageView setImage:[currentImageSource nextImageAndIdentifier:nil]];
}


- (IBAction)toggleFont:(id)sender
{
	NSString	*fontName = [availableFontNames	objectAtIndex:[fontsTableView selectedRow]];
	
	if ([[currentImageSource fontNames] containsObject:fontName])
		[currentImageSource removeFontWithName:fontName];
	else
		[currentImageSource addFontWithName:fontName];
	
	[fontsTableView reloadData];
}


- (IBAction)toggleColor:(id)sender
{
}


- (IBAction)setTextOption:(id)sender
{
}


- (IBAction)setCountOption:(id)sender
{
}


#pragma mark -
#pragma mark Table view data source methods


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == fontsTableView)
		return [availableFontNames count];
	else
		return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if (tableView == fontsTableView)
	{
		NSString	*fontName = [availableFontNames objectAtIndex:row];
		return [NSNumber numberWithBool:[[currentImageSource fontNames] containsObject:fontName]];
	}
	else
		return nil;
}


- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell 
											forTableColumn:(NSTableColumn *)tableColumn 
													   row:(int)row
{
	if (tableView == fontsTableView)
	{
		[cell setTitle:[availableFontNames objectAtIndex:row]];
		[cell setAction:@selector(toggleFont:)];
	}
}


- (void)dealloc
{
	[sampleTimer invalidate];	// which will also release it
	[availableFontNames release];
	
	[super dealloc];
}


@end
