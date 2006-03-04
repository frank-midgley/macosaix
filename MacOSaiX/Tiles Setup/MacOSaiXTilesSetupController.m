//
//  MacOSaiXTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/11/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTilesSetupController.h"

#import "MacOSaiX.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXTilesSetupController


- (NSString *)windowNibName
{
	return @"Tiles Setup";
}


- (void)setupTilesForMosaic:(MacOSaiXMosaic *)inMosaic 
			 modalForWindow:(NSWindow *)window 
			  modalDelegate:(id)inDelegate
			 didEndSelector:(SEL)inDidEndSelector;
{
	mosaic = inMosaic;
	delegate = inDelegate;
	didEndSelector = inDidEndSelector;
	
	[NSApp beginSheet:[self window] 
	   modalForWindow:window
		modalDelegate:self 
	   didEndSelector:@selector(tilesSetupDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (NSImage *)originalImage
{
	return [mosaic originalImage];
}


- (void)awakeFromNib
{
	[editorBox setContentViewMargins:NSMakeSize(16.0, 16.0)];
	
		// Populate the tile shapes pop-up with the names of the currently available plug-ins.
	[(MacOSaiX *)[NSApp delegate] discoverPlugIns];
	NSEnumerator	*enumerator = [[(MacOSaiX *)[NSApp delegate] tileShapesClasses] objectEnumerator];
	Class			tileShapesClass = nil;
	int				currentlyUsedClassIndex = -1;
	float			maxWidth = 0.0;
	NSString		*titleFormat = @"%@ Tile Shapes";
	[plugInsPopUp removeAllItems];
	while (tileShapesClass = [enumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:tileShapesClass];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSString		*title = [NSString stringWithFormat:titleFormat, plugInName];
		NSMenuItem		*newItem = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
		[newItem setRepresentedObject:tileShapesClass];
		NSImage			*image = [[[tileShapesClass image] copy] autorelease];
		[image setScalesWhenResized:YES];
		[image setSize:NSMakeSize(16.0, 16.0)];
		[newItem setImage:image];
		[[plugInsPopUp menu] addItem:newItem];
		
		[plugInsPopUp selectItem:newItem];
		[plugInsPopUp sizeToFit];
		maxWidth = MAX(maxWidth, [plugInsPopUp frame].size.width);
		
		if ([[[self mosaic] tileShapes] isKindOfClass:tileShapesClass])
			currentlyUsedClassIndex = [plugInsPopUp numberOfItems] - 1;
	}
	[plugInsPopUp setFrameSize:NSMakeSize(maxWidth, [plugInsPopUp frame].size.height)];
	[plugInsPopUp selectItemAtIndex:currentlyUsedClassIndex];
	
		// Populate the GUI with the current shape settings.
	[self setPlugIn:self];
	
		// Set the image rules controls.
	int				popUpIndex = [imageUseCountPopUp indexOfItemWithTag:[[self mosaic] imageUseCount]];
	[imageUseCountPopUp selectItemAtIndex:popUpIndex];
	popUpIndex = [imageReuseDistancePopUp indexOfItemWithTag:[[self mosaic] imageReuseDistance]];
	[imageReuseDistancePopUp selectItemAtIndex:popUpIndex];
	[imageCropLimitSlider setIntValue:[[self mosaic] imageCropLimit]];
}


- (void)updatePreview
{
	NSBezierPath	*previewPath = [editor previewPath];
	NSImage			*previewImage = nil;
	NSRect			previewPathBounds = [previewPath bounds];
	
	if (previewPath && NSWidth(previewPathBounds) > 0 && NSHeight(previewPathBounds) > 0)
	{
			// Scale the path to the image size.
		NSSize				previewSize = (NSWidth(previewPathBounds) > NSHeight(previewPathBounds) ? 
												NSMakeSize(96.0, 96.0 * NSHeight(previewPathBounds) / NSWidth(previewPathBounds)) : 
												NSMakeSize(96.0 * NSWidth(previewPathBounds) / NSHeight(previewPathBounds), 96.0));
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform scaleBy:96.0 / MAX(NSWidth(previewPathBounds), NSHeight(previewPathBounds))];
		[transform translateXBy:-NSMinX(previewPathBounds) yBy:-NSMinY(previewPathBounds)];
		[previewPath transformUsingAffineTransform:transform];
		
		[previewPath setLineWidth:2.0];
		
			// Create the preview image
		previewImage = [[NSImage alloc] initWithSize:NSMakeSize(previewSize.width + 4.0, 
																previewSize.height + 4.0)];
		[previewImage lockFocus];
			[[NSColor clearColor] set];
			NSRectFill(NSMakeRect(0.0, 0.0, previewSize.width, previewSize.height));
			
				// Draw the shadow.
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
			transform = [NSAffineTransform transform];
			[transform translateXBy:3.0 yBy:1.0];
			[[transform transformBezierPath:previewPath] stroke];
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
			transform = [NSAffineTransform transform];
			[transform translateXBy:2.0 yBy:2.0];
			[[transform transformBezierPath:previewPath] stroke];
			
				// Draw the path.
			transform = [NSAffineTransform transform];
			[transform translateXBy:1.0 yBy:3.0];
			[[NSColor whiteColor] set];
			[[transform transformBezierPath:previewPath] fill];
			[[NSColor blackColor] set];
			[[transform transformBezierPath:previewPath] stroke];
		[previewImage unlockFocus];
	}
	
//	static			count = 0;
//	[[previewImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0]
//		writeToFile:[NSString stringWithFormat:@"/Users/fmidgley/Desktop/Puzzle%3d.tiff", count++] atomically:NO];
	
	[previewImageView setImage:previewImage];
	[previewImage release];
}


- (IBAction)setPlugIn:(id)sender
{
	Class			tileShapesClass = [[plugInsPopUp selectedItem] representedObject],
					editorClass = [tileShapesClass editorClass];
	
	if (editorClass)
	{
			// Release any previous editor and create a new one using the selected class.
		[editor release];
		editor = [[editorClass alloc] initWithDelegate:self];
		
		[self updatePreview];
	
			// Swap in the view of the new editor.  Make sure the panel is big enough to contain the view's minimum size.
		float	widthDiff = MAX(0.0, [editor minimumSize].width - [[editorBox contentView] frame].size.width),
				heightDiff = MAX(0.0, [editor minimumSize].height - [[editorBox contentView] frame].size.height);
		[[editor editorView] setFrame:[[editorBox contentView] frame]];
		[[editor editorView] setAutoresizingMask:[[editorBox contentView] autoresizingMask]];
		[editorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		NSRect	frame = [[self window] frame];
		frame.origin.y -= heightDiff;
		frame.size.width += widthDiff;
		frame.size.height += heightDiff;
		[[self window] setFrame:frame display:YES animate:YES];
		[editorBox setContentView:[editor editorView]];
		
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
		[plugInsPopUp setNextKeyView:(NSView *)[editor firstResponder]];
		
			// Get the existing tile shapes from our mosaic.
			// If they are not of the class the user just chose then create a new one with default settings.
		if ([[[self mosaic] tileShapes] class] == tileShapesClass)
			tileShapesBeingEdited = [[[self mosaic] tileShapes] copyWithZone:[self zone]];
		else
			tileShapesBeingEdited = [[tileShapesClass alloc] init];
		
		[editor editTileShapes:tileShapesBeingEdited];
	}
	else
	{
		NSTextField	*errorView = [[[NSTextField alloc] initWithFrame:[[editorBox contentView] frame]] autorelease];
		
		[errorView setStringValue:@"Could not load the plug-in"];
		[errorView setEditable:NO];
	}
}


- (void)tileShapesWereEdited
{
	int		tileCount = [editor tileCount];
	
	if (tileCount > 0)
		[countField setIntValue:tileCount];
	else
		[countField setStringValue:@"Unknown"];
	
	NSSize	tileUnitSize = [[self mosaic] averageUnitTileSize],
			originalSize = [[[self mosaic] originalImage] size];
	float	aspectRatio = (tileUnitSize.width * originalSize.width) / 
						  (tileUnitSize.height * originalSize.height);
	[averageSizeField setStringValue:[NSString stringWithAspectRatio:aspectRatio]];

	[self updatePreview];
}


- (IBAction)setImageUseCount:(id)sender
{
	[[self mosaic] setImageUseCount:[[imageUseCountPopUp selectedItem] tag]];
}


- (IBAction)setImageReuseDistance:(id)sender
{
	[[self mosaic] setImageReuseDistance:[[imageReuseDistancePopUp selectedItem] tag]];
}


- (IBAction)setImageCropLimit:(id)sender
{
	[[self mosaic] setImageCropLimit:[imageCropLimitSlider intValue]];
}


- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}


- (IBAction)ok:(id)sender;
{
	[NSApp endSheet:[self window] returnCode:NSOKButton];
}


- (void)tilesSetupDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
		// Let the editor free up whatever resources it was using.
	[editor editingComplete];
	
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
	{
		[[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([tileShapesBeingEdited class])
												  forKey:@"Last Chosen Tile Shapes Class"];
		[[self mosaic] setTileShapes:tileShapesBeingEdited creatingTiles:YES];
	}
	
	[tileShapesBeingEdited release];
	tileShapesBeingEdited = nil;
	[editor release];
	editor = nil;
	
	[editorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
	
	if ([delegate respondsToSelector:@selector(didEndSelector)])
		[delegate performSelector:didEndSelector];
	
	mosaic = nil;
	delegate = nil;
	didEndSelector = nil;
}


- (NSSize)windowWillResize:(NSWindow *)resizingWindow toSize:(NSSize)proposedFrameSize
{
	if (resizingWindow == [self window])
	{
		NSSize	panelSize = [resizingWindow frame].size,
		editorBoxSize = [[editorBox contentView] frame].size;
		float	minWidth = (panelSize.width - editorBoxSize.width) + [editor minimumSize].width,
				minHeight = (panelSize.height - editorBoxSize.height) + [editor minimumSize].height;
		
		proposedFrameSize.width = MAX(proposedFrameSize.width, minWidth);
		proposedFrameSize.height = MAX(proposedFrameSize.height, minHeight);
	}
	
    return proposedFrameSize;
}


@end
