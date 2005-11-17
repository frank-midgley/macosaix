/*
	FlickrImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSourceController.h"


@implementation FlickrImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Flickr Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(414.0, 186.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return queryField;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (FlickrImageSource *)imageSource;
	
	[queryField setStringValue:([currentImageSource queryString] ? [currentImageSource queryString] : @"")];
	[queryTypeMatrix selectCellAtRow:[currentImageSource queryType] column:0];
}


- (IBAction)visitFlickr:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.flickr.com"]];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == queryField)
	{
		NSString	*queryString = [[queryField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		[currentImageSource setQueryString:queryString];
		
		[okButton setEnabled:([queryString length] > 0)];
	}
}


- (IBAction)setQueryType:(id)sender
{
	[currentImageSource setQueryType:[queryTypeMatrix selectedRow]];
}


@end
