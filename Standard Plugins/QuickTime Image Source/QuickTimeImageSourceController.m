//
//  QuickTimeImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "QuickTimeImageSourceController.h"
#import "QuickTimeImageSource.h"


@implementation QuickTimeImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"QuickTime Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(350.0, 220.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return chooseMovieFileButton;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
	
		// Set up to get notified when the window changes size so that we can adjust the
		// width of the movie view in a way that preserves the movie's aspect ratio.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowDidResize:) 
												 name:NSWindowDidResizeNotification 
											   object:[okButton window]];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
	[movieNameTextField setStringValue:[imageSource descriptor]];
	[movieView setMovie:[(QuickTimeImageSource *)imageSource movie]];
}


- (void)chooseMovie:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:nil
							  file:nil
							 types:nil	//[NSMovie movieUnfilteredFileTypes]
					modalForWindow:[editorView window]
					 modalDelegate:self
					didEndSelector:@selector(chooseMovieDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseMovieDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
			// Update the image source.
		[currentImageSource setPath:[[sheet filenames] objectAtIndex:0]];
		
			// Refresh the GUI from the updated image source.
		[movieNameTextField setStringValue:[currentImageSource descriptor]];
		[movieView setMovie:[currentImageSource movie]];
		
			// Update the recent movies pop-up menu
		
	}
	
	[okButton setEnabled:([currentImageSource movie] != nil)];
}


- (void)windowDidResize:(NSNotification *)notification
{
	if ([currentImageSource movie])
	{
		NSRect	movieFrame = [movieView frame];
		int		newMovieWidth = (movieFrame.size.height - 16.0) * [currentImageSource aspectRatio];
		
		movieFrame.size.width = newMovieWidth;
		movieFrame.origin.x = ([[movieView superview] frame].size.width - movieFrame.size.width) / 2.0;
		[movieView setFrame:movieFrame];
	}
}


- (void)dealloc
{
	[currentImageSource release];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	
	[super dealloc];
}


@end
