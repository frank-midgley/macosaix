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
#import "MacOSaiXPlugIn.h"


static NSMutableArray	*subClasses;

@implementation MacOSaiXMosaicEditor


+ (NSImage *)image
{
	NSImage	*image = [[[NSImage alloc] initWithSize:NSMakeSize(24.0, 16.0)] autorelease];
	
	[image lockFocus];
		[[NSColor blackColor] set];
		NSFrameRect(NSMakeRect(0.0, 0.0, 24.0, 16.0));
	[image unlockFocus];
	
	return image;
}


+ (void)load
{
	if (self == [MacOSaiXMosaicEditor class])
		subClasses = [[NSMutableArray alloc] init];
	else
	{
		[subClasses addObject:self];
		
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		[subClasses sortUsingSelector:@selector(compare:)];
		[pool release];
	}
}


+ (NSArray *)editorClasses
{
	return [NSArray arrayWithArray:subClasses];
}


+ (NSString *)title
{
	return @"";
}


+ (BOOL)isAdditional
{
	return NO;
}


+ (NSComparisonResult)compare:(Class)otherEditor
{
	if (![self isAdditional] && [otherEditor isAdditional])
		return NSOrderedAscending;
	else if ([self isAdditional] && ![otherEditor isAdditional])
		return NSOrderedDescending;
	else
		return [[self title] compare:[otherEditor title]];
}


+ (BOOL)descriptionHasBeenShown
{
	NSString	*editorDefault = [NSString stringWithFormat:@"%@ Description Shown", NSStringFromClass(self)];
	
	return [[NSUserDefaults standardUserDefaults] boolForKey:editorDefault];
}


+ (void)showDescriptionNearPoint:(NSPoint)descriptionPoint
{
	NSString		*windowTitle = [NSString stringWithFormat:NSLocalizedString(@"%@ Settings", @""), [self title]];
	NSWindow		*window = nil;
	
		// Check if the window is already open.
	NSEnumerator	*windowEnumerator = [[NSApp windows] objectEnumerator];
	while (window = [windowEnumerator nextObject])
		if ([window isKindOfClass:[NSPanel class]] && [[window title] isEqualToString:windowTitle])
			break;
	
	if (!window)
	{
		NSString	*editorDescription = [self description];
		NSRect		editorRect = NSMakeRect(descriptionPoint.x - 100.0, descriptionPoint.y - 50.0, 250.0, 100.0);
		// TODO: make sure the window is fully onscreen.
		
		window = [[NSPanel alloc] initWithContentRect:editorRect 
											styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSUtilityWindowMask) 
											  backing:NSBackingStoreBuffered 
												defer:NO];
		[window setTitle:windowTitle];
		[window setMinSize:editorRect.size];
		
		NSTextField	*textField = [[NSTextField alloc] initWithFrame:[[window contentView] bounds]];
		[textField setBordered:NO];
		[textField setStringValue:editorDescription];
		[textField setEditable:NO];
		[textField setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[[window contentView] addSubview:textField];
		
		[window setReleasedWhenClosed:YES];
	}
	
	[window makeKeyAndOrderFront:self];
	
	NSString	*editorDefault = [NSString stringWithFormat:@"%@ Description Shown", NSStringFromClass(self)];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:editorDefault];
}


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super init])
	{
		editorDelegate = delegate;
	}
	
	return self;
}


- (id<MacOSaiXMosaicEditorDelegate>)delegate
{
	return editorDelegate;
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
	return [[[self delegate] mosaic] targetImage];
}


- (void)setDataSource:(id<MacOSaiXDataSource>)dataSource value:(id)value forKey:(NSString *)key
{
	[(id)dataSource setValue:value forKey:key];
	
	[[self plugInEditor] refresh];
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource 
	  didChangeKey:(NSString *)key
		 fromValue:(id)previousValue 
		actionName:(NSString *)actionName;
{
	NSUndoManager		*undoManager = [[[self delegate] mosaic] undoManager];
	NSMethodSignature	*undoSignature = [self methodSignatureForSelector:@selector(setDataSource:value:forKey:)];
	NSInvocation		*undoInvocation = [NSInvocation invocationWithMethodSignature:undoSignature];
	
	[undoInvocation setTarget:self];
	[undoInvocation setSelector:@selector(setDataSource:value:forKey:)];
	[undoInvocation setArgument:&dataSource atIndex:2];
	[undoInvocation setArgument:&previousValue atIndex:3];
	[undoInvocation setArgument:&key atIndex:4];
	
	[undoManager prepareWithInvocationTarget:self];
	[undoManager forwardInvocation:undoInvocation];
	[undoManager setActionName:actionName];
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
				// End any editing before removing the view from the window.
			[[self delegate] makeFirstResponder:nil];
			
			[plugInEditor editingDidComplete];
			[plugInEditor release];
		}
		plugInEditor = [(id<MacOSaiXEditor>)[editorClass alloc] initWithDelegate:self];
		
			// Swap in the view of the new editor.  Make sure the window is big enough to contain the view's minimum size.
		[[plugInEditor editorView] setAutoresizingMask:[[plugInEditorBox contentView] autoresizingMask]];
		[plugInEditorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		
// TODO: shouldn't the window controller be setting this?  And -setContentMinSize is 10.3 and above.
// Something like [[self delegate] adjustMinimumSize]...
//		NSWindow	*window = [[[self delegate] mosaicView] window];
//		NSRect		frame = [window frame], 
//					contentFrame = [[window contentView] frame];
//		float		widthDiff = MAX(0.0, [plugInEditor minimumSize].width - [[plugInEditorBox contentView] frame].size.width),
//					heightDiff = MAX(0.0, [plugInEditor minimumSize].height - [[plugInEditorBox contentView] frame].size.height);
//					baseHeight = NSHeight(contentFrame) - NSHeight([[plugInEditorBox contentView] frame]) + 0.0, 
//					baseWidth = NSWidth(contentFrame) - NSWidth([[plugInEditorBox contentView] frame]) + 0.0;
//		if (NSWidth(contentFrame) + widthDiff < 426.0)
//			widthDiff = 426.0 - NSWidth(contentFrame);
//		if (NSHeight(contentFrame) + heightDiff < 434.0)
//			heightDiff = 434.0 - NSHeight(contentFrame);
//		frame.origin.x -= widthDiff / 2.0;
//		frame.origin.y -= heightDiff;
//		frame.size.width += widthDiff;
//		frame.size.height += heightDiff;
//		[window setContentMinSize:NSMakeSize(baseWidth + [plugInEditor minimumSize].width, baseHeight + [plugInEditor minimumSize].height)];
//		[window setFrame:frame display:YES animate:YES];
		
		[plugInEditorBox setContentView:[plugInEditor editorView]];
		
		// Re-establish the key view loop:
		// 1. Focus on the editor view's first responder.
		// 2. Set the next key view of the last view in the editor's loop to the cancel button.
		// 3. Set the next key view of the OK button to the first view in the editor's loop.
		[[self delegate] makeFirstResponder:[plugInEditor firstResponder]];
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


- (id<MacOSaiXDataSourceEditor>)plugInEditor
{
	return plugInEditor;
}


- (NSNumber *)targetImageOpacity
{
	return nil;	// current opacity is fine
}


- (void)beginEditing
{
	isActive = YES;
	
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


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect
{
	// Nothing for now...
}


- (void)handleEvent:(NSEvent *)event inMosaicView:(MosaicView *)mosaicView
{
	// TBD: double click = edit tile?
}


- (BOOL)endEditing
{
		// End any editing before the view is removed from the window.
	BOOL	success = [[self delegate] makeFirstResponder:nil];
	
	if (success)
	{
		[plugInEditor editingDidComplete];
		[plugInEditor release];
		plugInEditor = nil;
		
		isActive = NO;
	}
	
	return success;
}


- (BOOL)isActive
{
	return isActive;
}


- (void)dealloc
{
	editorDelegate = nil;
	
	[super dealloc];
}


@end
