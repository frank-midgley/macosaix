//
//  QuickTimeImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "QuickTimeImageSourceController.h"
#import "QuickTimeImageSource.h"


@implementation QuickTimeImageSourceController


+ (NSString *)name
{
	isalpha('a');	// get rid of weak linking warning
	return @"QuickTime";
}


- (NSView *)imageSourceView
{
	if (!_imageSourceView)
		[NSBundle loadNibNamed:@"QuickTime Image Source" owner:self];
	return _imageSourceView;
}


- (void)editImageSource:(ImageSource *)imageSource
{
	if (imageSource)
	{
		[_pathField setStringValue:[imageSource descriptor]];
		[_okButton setTitle:@"Save QuickTime Source"];
	}
	else
	{		// we're being asked to add a new image source
		[_pathField setStringValue:@""];
		[_okButton setTitle:@"Add QuickTime Source"];
		[self chooseMovie:self];
	}
}


- (void)chooseMovie:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:nil
			      file:nil
			     types:nil
		    modalForWindow:[self window]
		     modalDelegate:self
		    didEndSelector:@selector(chooseMovieDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)chooseMovieDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
		[_pathField setStringValue:[[sheet filenames] objectAtIndex:0]];
	[_okButton setEnabled:![[_pathField stringValue] isEqualToString:@""]];
}


- (void)addImageSource:(id)sender
{
	[[self document] addImageSource:[[[QuickTimeImageSource alloc] initWithPath:[_pathField stringValue]] autorelease]];
	[self showCurrentImageSources];
}


@end
