//
//  DirectoryImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourceController.h"
#import "DirectoryImageSource.h"


@implementation DirectoryImageSourceController


+ (NSString *)name
{
	isalpha('a');	// get rid of weak linking warning
	return @"Local Directory";
}


- (NSView *)imageSourceView
{
	if (!_imageSourceView)
		[NSBundle loadNibNamed:@"Directory Image Source" owner:self];
	return _imageSourceView;
}


- (void)editImageSource:(ImageSource *)imageSource
{
	if (imageSource)
	{
		[_pathField setStringValue:[imageSource descriptor]];
		[_okButton setTitle:@"Save Directory Source"];
	}
	else
	{		// we're being asked to add a new image source
		[_pathField setStringValue:@""];
		[_okButton setTitle:@"Add Directory Source"];
		[self chooseDirectory:self];
	}
}


- (void)chooseDirectory:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:nil
			      file:nil
			     types:nil
		    modalForWindow:[self window]
		     modalDelegate:self
		    didEndSelector:@selector(chooseDirectoryDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)chooseDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
		[_pathField setStringValue:[[sheet filenames] objectAtIndex:0]];
	[_okButton setEnabled:![[_pathField stringValue] isEqualToString:@""]];
}


- (void)addImageSource:(id)sender
{
	DirectoryImageSource	*newImageSource = [[DirectoryImageSource alloc] initWithPath:[_pathField stringValue]];
	
	[[self document] addImageSource:[newImageSource autorelease]];
	[self showCurrentImageSources];
}


@end
