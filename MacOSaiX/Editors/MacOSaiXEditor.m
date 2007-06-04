//
//  MacOSaiXEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXEditorsView.h"
#import "MacOSaiXMosaic.h"


@implementation MacOSaiXEditor


+ (NSImage *)image
{
	NSImage	*image = [[[NSImage alloc] initWithSize:NSMakeSize(24.0, 16.0)] autorelease];
	
	[image lockFocus];
		[[NSColor blackColor] set];
		NSFrameRect(NSMakeRect(0.0, 0.0, 24.0, 16.0));
	[image unlockFocus];
	
	return image;
}


- (id)initWithMosaicView:(MosaicView *)inMosaicView
{
	if (self = [super init])
	{
		mosaicView = inMosaicView;
	}
	
	return self;
}


- (MosaicView *)mosaicView
{
	return mosaicView;
}


- (NSString *)title
{
	return @"";
}


- (NSString *)editorNibName
{
	return nil;
}


- (NSView *)view
{
	if (!editorView)
		[NSBundle loadNibNamed:[self editorNibName] owner:self];
	
	return editorView;
}


- (void)updateMinimumViewSize
{
	[(MacOSaiXEditorsView *)[[self view] superview] updateMinimumViewSize];
}


- (NSSize)minimumViewSize
{
	return NSZeroSize;
}


- (NSView *)auxiliaryView
{
	if (!editorView)
		[NSBundle loadNibNamed:[self editorNibName] owner:self];
	
	return auxiliaryView;
}


- (NSArray *)plugInClasses
{
	return nil;
}


- (NSString *)plugInTitleFormat
{
	return nil;
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return nil;
}


- (NSImage *)targetImage
{
	return [[[self mosaicView] mosaic] targetImage];
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource settingsDidChange:(NSString *)changeDescription
{
	// Sub-classes to implement.
}


- (IBAction)setPlugInClass:(id)sender
{
	Class	plugInClass = [[plugInPopUpButton selectedItem] representedObject],
			dataSourceClass = [plugInClass dataSourceClass],
			editorClass = [plugInClass editorClass];
	
	if (editorClass)
	{
			// Release any previous editor and create a new one using the selected class.
		if (plugInEditor)
		{
			[plugInEditor editingDidComplete];
			[plugInEditor release];
		}
		plugInEditor = [[editorClass alloc] initWithDelegate:self];
		
			// Swap in the view of the new editor.  Make sure the window is big enough to contain the view's minimum size.
		NSWindow	*window = [[self mosaicView] window];
		NSRect		frame = [window frame], 
					contentFrame = [[window contentView] frame];
		float		widthDiff = MAX(0.0, [plugInEditor minimumSize].width - [[plugInEditorBox contentView] frame].size.width),
					heightDiff = MAX(0.0, [plugInEditor minimumSize].height - [[plugInEditorBox contentView] frame].size.height);
//					baseHeight = NSHeight(contentFrame) - NSHeight([[plugInEditorBox contentView] frame]) + 0.0, 
//					baseWidth = NSWidth(contentFrame) - NSWidth([[plugInEditorBox contentView] frame]) + 0.0;
		[[plugInEditor editorView] setAutoresizingMask:[[plugInEditorBox contentView] autoresizingMask]];
		[plugInEditorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		
		if (NSWidth(contentFrame) + widthDiff < 426.0)
			widthDiff = 426.0 - NSWidth(contentFrame);
		if (NSHeight(contentFrame) + heightDiff < 434.0)
			heightDiff = 434.0 - NSHeight(contentFrame);
		
		frame.origin.x -= widthDiff / 2.0;
		frame.origin.y -= heightDiff;
		frame.size.width += widthDiff;
		frame.size.height += heightDiff;
// TODO: shouldn't the window controller be setting this?  And -setContentMinSize is 10.3 and above.
//		[window setContentMinSize:NSMakeSize(baseWidth + [plugInEditor minimumSize].width, baseHeight + [plugInEditor minimumSize].height)];
//		[window setFrame:frame display:YES animate:YES];
		[plugInEditorBox setContentView:[plugInEditor editorView]];
		
		// Re-establish the key view loop:
		// 1. Focus on the editor view's first responder.
		// 2. Set the next key view of the last view in the editor's loop to the cancel button.
		// 3. Set the next key view of the OK button to the first view in the editor's loop.
		[window setInitialFirstResponder:(NSView *)[plugInEditor firstResponder]];
		NSView	*lastKeyView = (NSView *)[plugInEditor firstResponder];
		while ([lastKeyView nextKeyView] && 
			   [[lastKeyView nextKeyView] isDescendantOf:[plugInEditor editorView]] &&
			   [lastKeyView nextKeyView] != [plugInEditor firstResponder])
			lastKeyView = [lastKeyView nextKeyView];
		[lastKeyView setNextKeyView:plugInEditorNextKeyView];
		[plugInEditorPreviousKeyView setNextKeyView:(NSView *)[plugInEditor firstResponder]];
		
		// Get the existing tile shapes from our mosaic.
		// If they are not of the class the user just chose then create a new one with default settings.
		if ([[self mosaicDataSource] class] != dataSourceClass)
			[self setMosaicDataSource:[[[dataSourceClass alloc] init] autorelease]];
		
		[plugInEditor editDataSource:[self mosaicDataSource]];
	}
	else
	{
		NSTextField	*errorView = [[[NSTextField alloc] initWithFrame:[[plugInEditorBox contentView] frame]] autorelease];
		
		[errorView setStringValue:NSLocalizedString(@"Could not load the plug-in", @"")];
		[errorView setEditable:NO];
		
		[plugInEditorBox setContentView:errorView];
	}
	
	[self updateMinimumViewSize];
}


- (void)beginEditing
{
	if (plugInPopUpButton)
	{
			// Populate the pop-up with the names of the currently available plug-ins.
		NSEnumerator	*enumerator = [[self plugInClasses] objectEnumerator];
		Class			plugInClass = nil;
		NSString		*titleFormat = [self plugInTitleFormat];
		
		[plugInPopUpButton removeAllItems];
		while (plugInClass = [enumerator nextObject])
		{
			NSBundle		*plugInBundle = [NSBundle bundleForClass:plugInClass];
			NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
			NSString		*title = [NSString stringWithFormat:titleFormat, plugInName];
			NSMenuItem		*newItem = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
			[newItem setRepresentedObject:plugInClass];
			NSImage			*image = [[[plugInClass image] copy] autorelease];
			[image setScalesWhenResized:YES];
			[image setSize:NSMakeSize(16.0, 16.0)];
			[newItem setImage:image];
			[[plugInPopUpButton menu] addItem:newItem];
		}
		
		plugInClass = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[[self mosaicDataSource] class]];
		[plugInPopUpButton selectItemAtIndex:[plugInPopUpButton indexOfItemWithRepresentedObject:plugInClass]];
		[self setPlugInClass:self];
	}
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
}


- (void)endEditing
{
	[plugInEditor release];
	plugInEditor = nil;
}


- (void)dealloc
{
	mosaicView = nil;
	
	[super dealloc];
}


@end
