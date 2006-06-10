//
//  MacOSaiXImageSourceEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/23/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourceEditor.h"


@implementation MacOSaiXImageSourceEditor


- (NSString *)windowNibName
{
	return @"Image Source Editor";
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
				 mosaic:(MacOSaiXMosaic *)inMosaic
		 modalForWindow:(NSWindow *)window 
		  modalDelegate:(id)inDelegate
		 didEndSelector:(SEL)inDidEndSelector;
{
	mosaic = inMosaic;
	
	originalImageSource = imageSource;
	editedImageSource = [imageSource copyWithZone:[self zone]];
	
	delegate = inDelegate;
	didEndSelector = inDidEndSelector;
	
	editor = [[[[imageSource class] editorClass] alloc] init];
	
		// Make sure the panel is big enough to contain the view's minimum size.
	NSSize	currentPanelSize = [[[self window] contentView] frame].size, 
			newPanelSize = [self windowWillResize:[self window] toSize:currentPanelSize];
	float	widthDiff = newPanelSize.width - currentPanelSize.width, 
			heightDiff = newPanelSize.height - currentPanelSize.height, 
			baseWidth = currentPanelSize.width - NSWidth([[editorBox contentView] frame]), 
			baseHeight = currentPanelSize.height - NSHeight([[editorBox contentView] frame]);
	[[self window] setContentSize:newPanelSize];
	[[self window] setContentMinSize:NSMakeSize(baseWidth + [editor minimumSize].width, baseHeight + [editor minimumSize].height)];
	[[editor editorView] setFrame:[[editorBox contentView] frame]];
	[[editor editorView] setAutoresizingMask:[[editorBox contentView] autoresizingMask]];
	
	[[self window] setShowsResizeIndicator:(!NSEqualSizes([editor minimumSize], [editor maximumSize]) || 
											 NSEqualSizes([editor minimumSize], NSZeroSize))];
	
	// Now that the sheet is big enough we can swap in the controller's editor view.
	[editorBox setContentView:[editor editorView]];
	
	// Tell the editor to edit the source.
	[editor editImageSource:editedImageSource];
	
	// Re-establish the key view loop:
	// 1. Focus on the editor view's first responder.
	// 2. Set the next key view of the last view in the editor's loop to the cancel button.
	// 3. Set the next key view of the OK button to the first view in the editor's loop.
	[[self window] setInitialFirstResponder:(NSView *)[editor firstResponder]];
	NSView	*lastKeyView = (NSView *)[editor firstResponder];
	while ([lastKeyView nextKeyView] && 
		   [[lastKeyView nextKeyView] isDescendantOf:[editor editorView]] &&
		   [lastKeyView nextKeyView] != [editor firstResponder])
		lastKeyView = [lastKeyView nextKeyView];
	[lastKeyView setNextKeyView:cancelButton];
	[okButton setNextKeyView:(NSView *)[editor firstResponder]];
	
	[NSApp beginSheet:[self window] 
	   modalForWindow:window
		modalDelegate:self 
	   didEndSelector:@selector(editorDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}


- (void)windowEventDidOccur:(NSEvent *)event
{
	[okButton setEnabled:[editor settingsAreValid]];
}


- (NSSize)windowWillResize:(NSWindow *)resizingWindow toSize:(NSSize)proposedFrameSize
{
	if (resizingWindow == [self window])
	{
		NSSize	panelSize = [resizingWindow frame].size,
				editorBoxSize = [[editorBox contentView] frame].size, 
				minEditorSize = [editor minimumSize], 
				maxEditorSize = [editor maximumSize];
		
		if (NSEqualSizes(minEditorSize, NSZeroSize))
			minEditorSize = NSMakeSize(0.0, 0.0);
		if (NSEqualSizes(maxEditorSize, NSZeroSize))
			maxEditorSize = NSMakeSize(10000.0, 10000.0);
		
		float	borderWidth = panelSize.width - editorBoxSize.width,
				borderHeight = panelSize.height - editorBoxSize.height, 
				minWidth = borderWidth + minEditorSize.width, 
				minHeight = borderHeight + minEditorSize.height, 
				maxWidth = borderWidth + maxEditorSize.width, 
				maxHeight = borderHeight + maxEditorSize.height;
		
		proposedFrameSize.width = MIN(MAX(proposedFrameSize.width, minWidth), maxWidth);
		proposedFrameSize.height = MIN(MAX(proposedFrameSize.height, minHeight), maxHeight);
	}
	
	return proposedFrameSize;
}


- (IBAction)save:(id)sender;
{
	[NSApp endSheet:[self window] returnCode:NSOKButton];
}


- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}


- (void)editorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	[editorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
	
	[editor editImageSource:nil];
	[editor release];
	editor = nil;
	
		// Let our delegate know that editing has completed.
	if ([delegate respondsToSelector:didEndSelector])
		[delegate performSelector:didEndSelector 
					   withObject:(returnCode == NSOKButton ? editedImageSource : nil) 
					   withObject:(returnCode == NSOKButton ? originalImageSource : nil)];
	
	originalImageSource = nil;
	[editedImageSource release];
	editedImageSource = nil;
	mosaic = nil;
	
	delegate = nil;
	didEndSelector = nil;
}


@end
