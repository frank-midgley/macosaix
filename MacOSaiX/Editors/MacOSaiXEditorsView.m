//
//  MacOSaiXEditorsView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditorsView.h"

#import "MacOSaiXEditor.h"
#import "MacOSaiXWindowController.h"
#import "MosaicView.h"


@implementation MacOSaiXEditorsView


- (id)initWithFrame:(NSRect)frame
{
	if (self = [super initWithFrame:frame])
	{
		editors = [[NSMutableArray alloc] initWithCapacity:16];
		editorButtons = [[NSMutableArray alloc] initWithCapacity:16];
	}
	
	return self;
}


- (BOOL)isOpaque
{
	return NO;
}


- (void)setMosaicView:(MosaicView *)view
{
	mosaicView = view;
}


- (MosaicView *)mosaicView
{
	return mosaicView;
}


#define HEADER_HEIGHT 26.0


- (void)updateMinimumViewSize
{
		// Start with the minimum size needed for all of the editor buttons, including their auxiliary views.
	NSSize			minSize = NSMakeSize(0.0, HEADER_HEIGHT * [editorButtons count]);
	NSEnumerator	*editorEnumerator = [editors objectEnumerator];
	MacOSaiXEditor	*editor = nil;
	NSButton		*dummyButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, HEADER_HEIGHT)] autorelease];
	[dummyButton setAlignment:NSLeftTextAlignment];
	[dummyButton setImagePosition:NSImageLeft];
	[dummyButton setBezelStyle:NSShadowlessSquareBezelStyle];
	while (editor = [editorEnumerator nextObject])
	{
		[dummyButton setTitle:[editor title]];
		[dummyButton setImage:[[editor class] image]];
		[dummyButton sizeToFit];
		
		float	buttonWidth = NSWidth([dummyButton frame]);
		
		if ([editor auxiliaryView])
			buttonWidth += 4.0 + NSWidth([[editor auxiliaryView] frame]);
		
		if (buttonWidth > minSize.width)
			minSize.width = buttonWidth;
	}
	
		// Account for the active editor's space needs.
	NSSize	editorMinSize = [activeEditor minimumViewSize];
	minSize.width = MAX(minSize.width, editorMinSize.width);
	minSize.height += editorMinSize.height;
	
	MacOSaiXWindowController	*controller = [[self window] windowController];
	[controller setMinimumEditorsViewSize:minSize];
}


- (void)addEditor:(MacOSaiXEditor *)editor
{
	[editors addObject:editor];
	
	NSButton	*editorButton = nil;
	
	if ([editors count] == 1)
	{
		activeEditor = editor;
		
		editorButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, NSMaxY([self bounds]) - HEADER_HEIGHT, NSWidth([self bounds]), HEADER_HEIGHT)];
		[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
		
		[[activeEditor view] setFrame:NSMakeRect(0.0, 0.0, NSWidth([self bounds]), NSHeight([self bounds]) - HEADER_HEIGHT)];
		[[activeEditor view] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[self addSubview:[activeEditor view]];
		
		[activeEditor beginEditing];
		
		[[self mosaicView] setActiveEditor:activeEditor];
	}
	else
	{
		editorButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([self bounds]), HEADER_HEIGHT)];
		[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
		
			// Shrink the active editor view to make room for the new editor's button.
		NSRect	frame = [[activeEditor view] frame];
		frame.size.height -= HEADER_HEIGHT - 1.0;
		frame.origin.y += HEADER_HEIGHT - 1.0;
		[[activeEditor view] setFrame:frame];
		
			// Move the existing editor buttons to make room for the new one.
		int		index = [editors indexOfObjectIdenticalTo:activeEditor] + 1;
		for (; index < [editors count] - 1; index++)
		{
			NSButton	*editorButton = [editorButtons objectAtIndex:index];
			
			[editorButton setFrame:NSOffsetRect([editorButton frame], 0.0, HEADER_HEIGHT - 1.0)];
		}
	}
	
	[editorButton setTitle:[editor title]];
	[editorButton setAlignment:NSLeftTextAlignment];
	[editorButton setImagePosition:NSImageLeft];
	[editorButton setImage:[[editor class] image]];
	[editorButton setBezelStyle:NSShadowlessSquareBezelStyle];
	[editorButton setTarget:self];
	[editorButton setAction:@selector(showEditor:)];
	[self addSubview:editorButton];
	[editorButtons addObject:editorButton];
	
	if ([editor auxiliaryView])
	{
		NSView	*auxiliaryView = [editor auxiliaryView];
		float	viewWidth = NSWidth([auxiliaryView frame]), 
				viewHeight = NSHeight([auxiliaryView frame]);
		
		[auxiliaryView setFrame:NSMakeRect(NSMaxX([editorButton bounds]) - viewWidth, (HEADER_HEIGHT - viewHeight) / 2.0, viewWidth, viewHeight)];
		[auxiliaryView setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
		
		[editorButton addSubview:auxiliaryView];
	}
	
	[self setNeedsDisplay:YES];
}


- (NSArray *)editors
{
	return [NSArray arrayWithArray:editors];
}


- (void)setActiveEditor:(MacOSaiXEditor *)newEditor
{
	if (newEditor != activeEditor)
	{
		// TODO: animate
		
		int				previousEditorIndex = [editors indexOfObjectIdenticalTo:activeEditor], 
						newEditorIndex = [editors indexOfObjectIdenticalTo:newEditor];
		float			editorViewHeight = NSHeight([[activeEditor view] frame]);
		
		[activeEditor endEditing];
		
		[[activeEditor view] removeFromSuperview];
		
			// Move editor buttons up or down to make room for the new editor.
		if (previousEditorIndex < newEditorIndex)
		{
			int		editorIndex;
			for (editorIndex = previousEditorIndex + 1; editorIndex <= newEditorIndex; editorIndex++)
			{
				NSButton	*editorButton = [editorButtons objectAtIndex:editorIndex];
				
				[editorButton setFrame:NSOffsetRect([editorButton frame], 0.0, editorViewHeight)];
				[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
			}
		}
		else
		{
			int		editorIndex;
			for (editorIndex = newEditorIndex + 1; editorIndex <= previousEditorIndex; editorIndex++)
			{
				NSButton	*editorButton = [editorButtons objectAtIndex:editorIndex];
				
				[editorButton setFrame:NSOffsetRect([editorButton frame], 0.0, -editorViewHeight)];
				[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
			}
		}
		
		activeEditor = newEditor;
		
		[self updateMinimumViewSize];
		
		[[activeEditor view] setFrame:NSMakeRect(0.0, 
												 NSMinY([[editorButtons objectAtIndex:newEditorIndex] frame]) - editorViewHeight, 
												 NSWidth([self bounds]), 
												 editorViewHeight)];
		[[activeEditor view] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[self addSubview:[activeEditor view]];
		
		[activeEditor beginEditing];
		
		[self setNeedsDisplay:YES];
		
		[[self mosaicView] setActiveEditor:activeEditor];
	}
}


- (MacOSaiXEditor *)activeEditor
{
	return activeEditor;
}


- (IBAction)showEditor:(id)sender
{
	[self setActiveEditor:[editors objectAtIndex:[editorButtons indexOfObjectIdenticalTo:sender]]];
}


- (void)drawRect:(NSRect)rect
{
	[[NSColor grayColor] set];
	NSFrameRect([self bounds]);
	
	[super drawRect:rect];
}


- (void)dealloc
{
	[editors release];
	[editorButtons release];
	
	[super dealloc];
}


@end
