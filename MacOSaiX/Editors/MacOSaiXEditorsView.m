//
//  MacOSaiXEditorsView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditorsView.h"

#import "MacOSaiXEditor.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXWindowController.h"
#import "MosaicView.h"


@interface MacOSaiXEditorsView (PrivateMethods)
- (void)tile;
@end

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


- (void)viewDidMoveToWindow
{
	if ([self window] && !additionalEditorsPopUp)
	{
		NSRect	popUpFrame = [self frame];
		popUpFrame.size.height = 24.0;
		additionalEditorsPopUp = [[NSPopUpButton alloc] initWithFrame:popUpFrame pullsDown:YES];
		[additionalEditorsPopUp setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
		[additionalEditorsPopUp addItemWithTitle:NSLocalizedString(@"Additional Settings...", @"")];
		[additionalEditorsPopUp setBezelStyle:NSShadowlessSquareBezelStyle];
		
		NSEnumerator	*editorEnumerator = [[MacOSaiXMosaicEditor editorClasses] objectEnumerator];
		Class			editorClass = nil;
		while (editorClass = [editorEnumerator nextObject])
		{
			if ([editorClass isAdditional])
			{
				NSMenuItem	*editorItem = [[NSMenuItem alloc] initWithTitle:@"" 
																	 action:@selector(toggleEditorDisplay:) 
															  keyEquivalent:@""];
				[editorItem setTarget:self];
				[editorItem setRepresentedObject:editorClass];
				
				[[additionalEditorsPopUp menu] addItem:editorItem];
			}
			
			if (![editorClass isAdditional] || [[self mosaic] editorClassIsVisible:editorClass])
				[self setEditorClass:editorClass isVisible:YES];
		}
		
		[[additionalEditorsPopUp menu] addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem		*setDefaultItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show These Settings For New Mosaics", @"") 
																	 action:@selector(setDefaultVisibleEditors:) 
															  keyEquivalent:@""];
		[setDefaultItem setTarget:self];
		[[additionalEditorsPopUp menu] addItem:setDefaultItem];
		
		[self addSubview:additionalEditorsPopUp];
		
		[self setActiveEditor:[editors objectAtIndex:0]];
	}
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


- (MacOSaiXMosaic *)mosaic
{
	return [mosaicView mosaic];
}



#define HEADER_HEIGHT 25.0


- (void)updateMinimumViewSize
{
		// Start with the minimum size needed for all of the editor buttons, including their auxiliary views.
	NSSize						minSize = NSMakeSize(0.0, HEADER_HEIGHT * [editorButtons count] + NSHeight([additionalEditorsPopUp frame]));
	NSEnumerator				*editorEnumerator = [editors objectEnumerator];
	MacOSaiXMosaicEditor		*editor = nil;
	NSButton					*dummyButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, HEADER_HEIGHT + 1.0)] autorelease];
	[dummyButton setAlignment:NSLeftTextAlignment];
	[dummyButton setImagePosition:NSImageLeft];
	[dummyButton setBezelStyle:NSShadowlessSquareBezelStyle];
	while (editor = [editorEnumerator nextObject])
	{
		[dummyButton setTitle:[[editor class] title]];
		[dummyButton setImage:[[editor class] image]];
		[dummyButton sizeToFit];
		
		float	buttonWidth = NSWidth([dummyButton frame]);
		
		if ([editor auxiliaryView])
			buttonWidth += 4.0 + NSWidth([[editor auxiliaryView] frame]);
		
		if (buttonWidth > minSize.width)
			minSize.width = buttonWidth;
	}
	
		// Account for the active editor's space needs.
	NSSize						editorMinSize = [activeEditor minimumViewSize];
	minSize.width = MAX(minSize.width, editorMinSize.width);
	minSize.height += editorMinSize.height;
	
	MacOSaiXWindowController	*controller = [[self window] windowController];
	[controller setMinimumEditorsViewSize:minSize];
}


- (NSArray *)editors
{
	return [NSArray arrayWithArray:editors];
}


- (BOOL)setActiveEditor:(MacOSaiXMosaicEditor *)newEditor
{
	BOOL	success = YES;
	
	if (newEditor != activeEditor)
	{
		if (activeEditor)
			success = [activeEditor endEditing];
		
		if (success)
		{
				// Remove the previous editor's view.
			[[activeEditor view] removeFromSuperview];
			
				// Switch to the new editor and enlarge our frame if needed.
			activeEditor = newEditor;
			[self updateMinimumViewSize];
			
				// Add the new editor's view and re-layout the view.
			float			editorViewHeight = NSHeight([self bounds]) - [editors count] * HEADER_HEIGHT - NSHeight([additionalEditorsPopUp frame]);
			[[activeEditor view] setFrame:NSMakeRect(0.0, 0.0, NSWidth([self bounds]), editorViewHeight)];
			[[activeEditor view] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
			[self addSubview:[activeEditor view]];
			[self tile];
			
				// Activate the new editor.
			[activeEditor beginEditing];
		
			// TBD: needed?
			//[self setNeedsDisplay:YES];
			
			[self embellishmentNeedsDisplay];
		}
	}
	
	return success;
}


- (MacOSaiXMosaicEditor *)activeEditor
{
	return activeEditor;
}


- (MacOSaiXMosaicEditor *)editorForClass:(Class)editorClass
{
	NSEnumerator			*editorEnumerator = [editors objectEnumerator];
	MacOSaiXMosaicEditor	*editor = nil;
	while (editor = [editorEnumerator nextObject])
		if ([editor class] == editorClass)
			break;
	
	return editor;
}


- (BOOL)setActiveEditorClass:(Class)editorClass
{
	MacOSaiXMosaicEditor	*editor = [self editorForClass:editorClass];
	
	if (!editor)
	{
		[self setEditorClass:editorClass isVisible:YES];
		editor = [self editorForClass:editorClass];
	}
	
	return [self setActiveEditor:editor];
}


- (Class)activeEditorClass
{
	return [[self activeEditor] class];
}


- (IBAction)showEditor:(id)sender
{
	[self setActiveEditorClass:[[sender cell] representedObject]];
}


- (BOOL)makeFirstResponder:(NSResponder *)responder
{
	return [[mosaicView window] makeFirstResponder:responder];
}


- (void)drawRect:(NSRect)rect
{
	[[NSColor grayColor] set];
	NSFrameRect([self bounds]);
	
	[super drawRect:rect];
}


- (void)embellishmentNeedsDisplay
{
	[mosaicView setNeedsDisplay:YES];
}


- (void)tile
{
	// Arrange all of the buttons and the active editor's view.
	
	NSEnumerator			*editorEnumerator = [editors objectEnumerator];
	MacOSaiXMosaicEditor	*editor = nil;
	NSRect					buttonFrame = NSMakeRect(0.0, NSMaxY([self bounds]) - HEADER_HEIGHT - 1.0, NSWidth([self bounds]), HEADER_HEIGHT + 1.0);
	BOOL					aboveActiveEditor = YES;
	
	while (editor = [editorEnumerator nextObject])
	{
		NSButton	*editorButton = [editorButtons objectAtIndex:[editors indexOfObjectIdenticalTo:editor]];
		[editorButton setFrame:buttonFrame];
		if (aboveActiveEditor)
			[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
		else
			[editorButton setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
		
		if (editor == [self activeEditor])
		{
			float	editorHeight = NSHeight([self bounds]) - HEADER_HEIGHT * [editors count] - NSHeight([additionalEditorsPopUp frame]) - 1.0;
			NSRect	editorFrame = NSMakeRect(0.0, NSMinY(buttonFrame) - editorHeight, NSWidth([self bounds]), editorHeight);
			
			[[[self activeEditor] view] setFrame:editorFrame];
			
			buttonFrame.origin.y = NSMinY(editorFrame) - HEADER_HEIGHT - 1.0;
			aboveActiveEditor = NO;
		}
		else
			buttonFrame.origin.y -= HEADER_HEIGHT;
	}
}


- (void)setEditorClass:(Class)editorClass isVisible:(BOOL)isVisible
{
	if (isVisible)
	{
			// Create the editor.
		MacOSaiXMosaicEditor	*editor = [[editorClass alloc] initWithDelegate:self];
		
			// Create the editor's button.  It's origin doesn't matter as it will be set by -tile below.  The size matters for adding any auxiliary view.
		NSButton				*editorButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([self bounds]), HEADER_HEIGHT + 1.0)];
		[editorButton setTitle:[editorClass title]];
		[editorButton setAlignment:NSLeftTextAlignment];
		[editorButton setImagePosition:NSImageLeft];
		[editorButton setImage:[editorClass image]];
		[editorButton setBezelStyle:NSShadowlessSquareBezelStyle];
		[editorButton setTarget:self];
		[editorButton setAction:@selector(showEditor:)];
		[[editorButton cell] setRepresentedObject:editorClass];
		if ([editor auxiliaryView])
		{
			NSView	*auxiliaryView = [editor auxiliaryView];
			float	viewWidth = NSWidth([auxiliaryView frame]), 
					viewHeight = NSHeight([auxiliaryView frame]);
			
			[auxiliaryView setFrame:NSMakeRect(NSMaxX([editorButton bounds]) - viewWidth, (HEADER_HEIGHT - viewHeight) / 2.0, viewWidth, viewHeight)];
			[auxiliaryView setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
			
			[editorButton addSubview:auxiliaryView];
		}
		[self addSubview:editorButton];
		
			// Figure out where the editor should go.  The editors array will be a subset of [MacOSaiXMosaicEditor editorClasses] and should be in the same order.
		NSArray					*editorClassOrder = [MacOSaiXMosaicEditor editorClasses];
		int						newIndex = [editorClassOrder indexOfObject:editorClass], 
								curIndex = 0;
		if ([editors count] > 0)
			while (curIndex < [editors count] && [editorClassOrder indexOfObject:[[editors objectAtIndex:curIndex] class]] < newIndex)
				curIndex++;
		if (curIndex < [editors count] - 1)
		{
			[editors insertObject:editor atIndex:curIndex];
			[editorButtons insertObject:editorButton atIndex:curIndex];
		}
		else
		{
			[editors addObject:editor];
			[editorButtons addObject:editorButton];
		}
		
		[self tile];
		
		[[mosaicView mosaic] setEditorClass:editorClass isVisible:YES];
	}
	else
	{
			// Remove the editor.
		MacOSaiXMosaicEditor	*editor = [self editorForClass:editorClass];
		int						editorIndex = [editors indexOfObjectIdenticalTo:editor];
		
		if (editor != [self activeEditor] || [self setActiveEditor:[editors objectAtIndex:editorIndex - 1]])
		{
			[[editorButtons objectAtIndex:editorIndex] removeFromSuperview];
			[editorButtons removeObjectAtIndex:editorIndex];
			[editors removeObjectAtIndex:editorIndex];
			
			[self tile];
					
			[[mosaicView mosaic] setEditorClass:editorClass isVisible:NO];
		}
	}
}


- (IBAction)toggleEditorDisplay:(id)sender
{
	Class	editorClass = [sender representedObject];
	
	if ([self editorForClass:editorClass])
		[self setEditorClass:editorClass isVisible:NO];
	else
	{
		[self setEditorClass:editorClass isVisible:YES];
		[self setActiveEditorClass:editorClass];
		
			// Show the editor's description if the user hasn't seen it before.
		if ([editorClass isAdditional] && ![editorClass descriptionHasBeenShown])
		{
			NSRect	editorFrame = [[[self activeEditor] view] frame];
			NSPoint	descriptionPoint = [self convertPoint:NSMakePoint(NSMaxX(editorFrame), NSMidY(editorFrame)) toView:nil];
			
			[editorClass showDescriptionNearPoint:[[self window] convertBaseToScreen:descriptionPoint]];
		}
	}
}


- (IBAction)setDefaultVisibleEditors:(id)sender
{
	NSMutableArray			*additionalEditors = [NSMutableArray array];
	NSEnumerator			*editorEnumerator = [editors objectEnumerator];
	MacOSaiXMosaicEditor	*editor = nil;
	
	while (editor = [editorEnumerator nextObject])
		if ([[editor class] isAdditional])
			[additionalEditors addObject:NSStringFromClass([editor class])];
	
	NSUserDefaults			*defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:additionalEditors forKey:@"Default Additional Editors"];
	[defaults synchronize];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(toggleEditorDisplay:))
	{
		Class	editorClass = [menuItem representedObject];
		
		if ([self editorForClass:editorClass])
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Hide %@ Settings", @""), [editorClass title]]];
		else
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Show %@ Settings", @""), [editorClass title]]];
	}
	
	return YES;
}


- (void)dealloc
{
	[editors release];
	[editorButtons release];
	
	[super dealloc];
}


@end
