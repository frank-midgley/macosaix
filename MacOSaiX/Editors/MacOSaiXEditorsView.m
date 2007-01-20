//
//  MacOSaiXEditorsView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditorsView.h"

#import "MacOSaiXEditor.h"
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
		
		NSRect	frame = [[activeEditor view] frame];
		frame.size.height -= HEADER_HEIGHT - 1.0;
		frame.origin.y += HEADER_HEIGHT - 1.0;
		[[activeEditor view] setFrame:frame];
		
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
	[editorButton setImage:[editor image]];
	[editorButton setBezelStyle:NSShadowlessSquareBezelStyle];
	[editorButton setTarget:self];
	[editorButton setAction:@selector(showEditor:)];
	[self addSubview:editorButton];
	[editorButtons addObject:editorButton];
	
	[self setNeedsDisplay:YES];
}


- (NSArray *)editors
{
	return [NSArray arrayWithArray:editors];
}


- (MacOSaiXEditor *)activeEditor
{
	return activeEditor;
}


- (IBAction)showEditor:(id)sender
{
	// TODO: animate
	
	MacOSaiXEditor	*newEditor = [editors objectAtIndex:[editorButtons indexOfObjectIdenticalTo:sender]];
	int				previousEditorIndex = [editors indexOfObjectIdenticalTo:activeEditor], 
					newEditorIndex = [editors indexOfObjectIdenticalTo:newEditor];
	float			editorViewHeight = NSHeight([[activeEditor view] frame]);
	
	[activeEditor endEditing];
	
	[[activeEditor view] removeFromSuperview];
	
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
	
	// TODO: make self and/or window larger if needed.
	
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


- (void)drawRect:(NSRect)rect
{
	[[NSColor grayColor] set];
	NSFrameRect(rect);
	
	[super drawRect:rect];
}


- (void)dealloc
{
	[editors release];
	[editorButtons release];
	
	[super dealloc];
}


@end
