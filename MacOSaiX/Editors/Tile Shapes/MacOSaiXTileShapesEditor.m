//
//  MacOSaiXTileShapesEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapesEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXPlugIn.h"
#import "MacOSaiXTileShapes.h"


@implementation MacOSaiXTileShapesEditor


- (id)initWithMosaicView:(MosaicView *)inMosaicView
{
	if (self = [super initWithMosaicView:inMosaicView])
	{
		tileShapesToDraw = [[NSMutableArray alloc] initWithCapacity:16];
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Tile Shapes Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Tile Shapes", @"");
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:1.0];
	
		// Populate the tile shapes pop-up with the names of the currently available plug-ins.
	NSEnumerator	*enumerator = [[(MacOSaiX *)[NSApp delegate] tileShapesPlugIns] objectEnumerator];
	Class			tileShapesPlugIn = nil;
	NSString		*titleFormat = NSLocalizedString(@"%@ Tile Shapes", @"");
	[tileShapesPlugInPopUp removeAllItems];
	while (tileShapesPlugIn = [enumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:tileShapesPlugIn];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSString		*title = [NSString stringWithFormat:titleFormat, plugInName];
		NSMenuItem		*newItem = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
		[newItem setRepresentedObject:tileShapesPlugIn];
		NSImage			*image = [[[tileShapesPlugIn image] copy] autorelease];
		[image setScalesWhenResized:YES];
		[image setSize:NSMakeSize(16.0, 16.0)];
		[newItem setImage:image];
		[[tileShapesPlugInPopUp menu] addItem:newItem];
	}
	
//	[self populateTileAreas];
	
	id<MacOSaiXTileShapes>	tileShapes = [[[self mosaicView] mosaic] tileShapes];
	Class					plugInClass = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[tileShapes class]];
	[tileShapesPlugInPopUp selectItemAtIndex:[tileShapesPlugInPopUp indexOfItemWithRepresentedObject:plugInClass]];
	[self setTileShapesClass:self];
}


- (IBAction)setTileShapesClass:(id)sender
{
	Class	tileShapesPlugIn = [[tileShapesPlugInPopUp selectedItem] representedObject],
			tileShapesClass = [tileShapesPlugIn dataSourceClass],
			editorClass = [tileShapesPlugIn dataSourceEditorClass];
	
	if (editorClass)
	{
			// Release any previous editor and create a new one using the selected class.
		if (tileShapesEditor)
		{
			[tileShapesEditor editingDidComplete];
			[tileShapesEditor release];
		}
		tileShapesEditor = [[editorClass alloc] initWithDelegate:self];
		
			// Swap in the view of the new editor.  Make sure the panel is big enough to contain the view's minimum size.
		NSWindow	*window = [[self mosaicView] window];
		NSRect		frame = [window frame], 
					contentFrame = [[window contentView] frame];
		float		widthDiff = MAX(0.0, [tileShapesEditor minimumSize].width - [[tileShapesEditorBox contentView] frame].size.width),
					heightDiff = MAX(0.0, [tileShapesEditor minimumSize].height - [[tileShapesEditorBox contentView] frame].size.height), 
					baseHeight = NSHeight(contentFrame) - NSHeight([[tileShapesEditorBox contentView] frame]) + 0.0, 
					baseWidth = NSWidth(contentFrame) - NSWidth([[tileShapesEditorBox contentView] frame]) + 0.0;
		[[tileShapesEditor editorView] setAutoresizingMask:[[tileShapesEditorBox contentView] autoresizingMask]];
		[tileShapesEditorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		
		if (NSWidth(contentFrame) + widthDiff < 426.0)
			widthDiff = 426.0 - NSWidth(contentFrame);
		if (NSHeight(contentFrame) + heightDiff < 434.0)
			heightDiff = 434.0 - NSHeight(contentFrame);
		
		frame.origin.x -= widthDiff / 2.0;
		frame.origin.y -= heightDiff;
		frame.size.width += widthDiff;
		frame.size.height += heightDiff;
		[window setContentMinSize:NSMakeSize(baseWidth + [tileShapesEditor minimumSize].width, baseHeight + [tileShapesEditor minimumSize].height)];
		[window setFrame:frame display:YES animate:YES];
		[tileShapesEditorBox setContentView:[tileShapesEditor editorView]];
		
			// Re-establish the key view loop:
			// 1. Focus on the editor view's first responder.
			// 2. Set the next key view of the last view in the editor's loop to the cancel button.
			// 3. Set the next key view of the OK button to the first view in the editor's loop.
		[window setInitialFirstResponder:(NSView *)[tileShapesEditor firstResponder]];
		NSView	*lastKeyView = (NSView *)[tileShapesEditor firstResponder];
		while ([lastKeyView nextKeyView] && 
			   [[lastKeyView nextKeyView] isDescendantOf:[tileShapesEditor editorView]] &&
			   [lastKeyView nextKeyView] != [tileShapesEditor firstResponder])
			lastKeyView = [lastKeyView nextKeyView];
		[lastKeyView setNextKeyView:discardChangesButton];
		[tileShapesPlugInPopUp setNextKeyView:(NSView *)[tileShapesEditor firstResponder]];
		
			// Get the existing tile shapes from our mosaic.
			// If they are not of the class the user just chose then create a new one with default settings.
		if ([[[[self mosaicView] mosaic] tileShapes] class] != tileShapesClass)
				[[[self mosaicView] mosaic] setTileShapes:[[[tileShapesClass alloc] init] autorelease] creatingTiles:YES];
		
		[tileShapesEditor editDataSource:[[[self mosaicView] mosaic] tileShapes]];
	}
	else
	{
		NSTextField	*errorView = [[[NSTextField alloc] initWithFrame:[[tileShapesEditorBox contentView] frame]] autorelease];
		
		[errorView setStringValue:NSLocalizedString(@"Could not load the plug-in", @"")];
		[errorView setEditable:NO];
		
		[tileShapesEditorBox setContentView:errorView];
	}
}


- (void)continueEmbellishingMosaicView
{
	NSDate					*startTime = [NSDate date];
	
	[[self mosaicView] lockFocus];
	
	NSRect					imageBounds = [[self mosaicView] imageBounds];
	NSSize					targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
	NSAffineTransform		*darkenTransform = [NSAffineTransform transform], 
							*lightenTransform = [NSAffineTransform transform];
	[darkenTransform translateXBy:NSMinX(imageBounds) - 0.5 yBy:NSMinY(imageBounds) + 0.5];
	[darkenTransform scaleXBy:NSWidth(imageBounds) / targetImageSize.width 
						  yBy:NSHeight(imageBounds) / targetImageSize.height];
	[lightenTransform translateXBy:NSMinX(imageBounds) + 0.5 yBy:NSMinY(imageBounds) - 0.5];
	[lightenTransform scaleXBy:NSWidth(imageBounds) / targetImageSize.width 
						   yBy:NSHeight(imageBounds) / targetImageSize.height];
	NSColor					*darkenColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.25], 
							*lightenColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.25];
	
	while ([tileShapesToDraw count] > 0 && [startTime timeIntervalSinceNow] > -0.05)
	{
		NSBezierPath	*tileOutline = [[tileShapesToDraw objectAtIndex:0] outline];
		
		[darkenColor set];
		[[darkenTransform transformBezierPath:tileOutline] stroke];
		[lightenColor set];
		[[lightenTransform transformBezierPath:tileOutline] stroke];
		
		[tileShapesToDraw removeObjectAtIndex:0];
	}

	[[NSGraphicsContext currentContext] flushGraphics];
	
	[[self mosaicView] unlockFocus];
	
	if ([tileShapesToDraw count] > 0)
		[self performSelector:_cmd withObject:nil afterDelay:0.0];
}


- (void)embellishMosaicViewInRect:(NSRect)updateRect
{
	if (![[self mosaicView] inLiveResize])
	{
		NSSize	targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
		
		[tileShapesToDraw removeAllObjects];
		[tileShapesToDraw addObjectsFromArray:[[[[self mosaicView] mosaic] tileShapes] shapesForMosaicOfSize:targetImageSize]];
		
		[self continueEmbellishingMosaicView];
	}
}


- (NSImage *)targetImage
{
	return [[[self mosaicView] mosaic] targetImage];
}


- (void)plugInSettingsDidChange:(NSString *)description
{
	[[[self mosaicView] mosaic] setTileShapes:[[[self mosaicView] mosaic] tileShapes] creatingTiles:YES];
	
	//[self populateTileAreas];
	
	[[self mosaicView] setNeedsDisplay:YES];
}


- (void)endEditing
{
	[tileShapesToDraw removeAllObjects];
	
	[tileShapesEditor release];
	tileShapesEditor = nil;
}


- (void)dealloc
{
	[tileShapesToDraw release];
	
	[super dealloc];
}


@end
