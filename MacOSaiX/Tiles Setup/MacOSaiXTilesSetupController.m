//
//  MacOSaiXTilesSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/11/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTilesSetupController.h"

#import "MacOSaiX.h"
#import "MacOSaiXWarningController.h"
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
	
	[self window];
	
		// Populate the GUI with the current shape settings.
	[plugInsPopUp selectItemAtIndex:[plugInsPopUp indexOfItemWithRepresentedObject:[[mosaic tileShapes] class]]];
	[self setPlugIn:self];
	NSRect	frame = [[self window] frame];
	NSSize	minSize = [[self window] minSize];
	if (NSWidth(frame) < minSize.width)
		frame.size.width = minSize.width;
	if (NSHeight(frame) < minSize.height)
		frame.size.height = minSize.height;
	[[self window] setFrame:frame display:NO];
	
		// Set the image rules controls.
	int				popUpIndex = [imageUseCountPopUp indexOfItemWithTag:[mosaic imageUseCount]];
	[imageUseCountPopUp selectItemAtIndex:popUpIndex];
	[imageReuseSlider setIntValue:[mosaic imageReuseDistance]];
	[imageCropLimitSlider setIntValue:[mosaic imageCropLimit]];
	
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
	[editorBox setContentViewMargins:NSMakeSize(0.0, 0.0)];
	
		// Populate the tile shapes pop-up with the names of the currently available plug-ins.
		// TODO: listen for a notification from the app delegate that the list changed and re-populate.
	[(MacOSaiX *)[NSApp delegate] discoverPlugIns];
	NSEnumerator	*enumerator = [[(MacOSaiX *)[NSApp delegate] tileShapesClasses] objectEnumerator];
	Class			tileShapesClass = nil;
	float			maxWidth = 0.0;
	NSString		*titleFormat = NSLocalizedString(@"%@ Tile Shapes", @"");
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
	}
	[plugInsPopUp setFrameSize:NSMakeSize(maxWidth, [plugInsPopUp frame].size.height)];
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
		
		float	tileAspectRatio = NSWidth(previewPathBounds) / NSHeight(previewPathBounds);
		[tileSizeField setStringValue:[NSString stringWithAspectRatio:tileAspectRatio]];
	}
	else
		[tileSizeField setStringValue:@"--"];
	
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
		if (editor)
		{
			[editor editingComplete];
			[editor release];
		}
		editor = [[editorClass alloc] initWithOriginalImage:[[self mosaic] originalImage]];
		
		[self updatePreview];
	
			// Swap in the view of the new editor.  Make sure the panel is big enough to contain the view's minimum size.
		NSRect	frame = [[self window] frame], 
				contentFrame = [[[self window] contentView] frame];
		float	widthDiff = MAX(0.0, [editor minimumSize].width - [[editorBox contentView] frame].size.width),
				heightDiff = MAX(0.0, [editor minimumSize].height - [[editorBox contentView] frame].size.height), 
				baseHeight = NSHeight(contentFrame) - NSHeight([[editorBox contentView] frame]) + 0.0, 
				baseWidth = NSWidth(contentFrame) - NSWidth([[editorBox contentView] frame]) + 0.0;
		[[editor editorView] setAutoresizingMask:[[editorBox contentView] autoresizingMask]];
		[editorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		
		if (NSWidth(contentFrame) + widthDiff < 426.0)
			widthDiff = 426.0 - NSWidth(contentFrame);
		if (NSHeight(contentFrame) + heightDiff < 434.0)
			heightDiff = 434.0 - NSHeight(contentFrame);
		
		frame.origin.x -= widthDiff / 2.0;
		frame.origin.y -= heightDiff;
		frame.size.width += widthDiff;
		frame.size.height += heightDiff;
		[[self window] setContentMinSize:NSMakeSize(baseWidth + [editor minimumSize].width, baseHeight + [editor minimumSize].height)];
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
		
		[errorView setStringValue:NSLocalizedString(@"Could not load the plug-in", @"")];
		[errorView setEditable:NO];
		
		[editorBox setContentView:errorView];
	}
}


- (IBAction)setImageUseCount:(id)sender
{
	[imageReuseSlider setEnabled:([[imageUseCountPopUp selectedItem] tag] != 1)];
}


- (void)windowEventDidOccur:(NSEvent *)event
{
	[self updatePreview];
	
	int		tileCount = [editor tileCount];
	if (tileCount > 0)
		[countField setIntValue:tileCount];
	else
		[countField setStringValue:NSLocalizedString(@"Unknown", @"")];
	
	[okButton setEnabled:[editor settingsAreValid]];
}


- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}


- (IBAction)ok:(id)sender;
{
		// TBD: some changes may not require resetting
	if (![[self mosaic] wasStarted] || 
		![MacOSaiXWarningController warningIsEnabled:@"Changing Tiles Setup"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Changing Tiles Setup" 
												title:NSLocalizedString(@"Do you wish to change the tiles setup?", @"") 
											  message:NSLocalizedString(@"All work in the current mosaic will be lost.", @"") 
										 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
		[NSApp endSheet:[self window] returnCode:NSOKButton];
}


- (void)tilesSetupDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
	{
		[[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([tileShapesBeingEdited class])
												  forKey:@"Last Chosen Tile Shapes Class"];
		[[self mosaic] setTileShapes:tileShapesBeingEdited creatingTiles:YES];
		[[self mosaic] setImageUseCount:[[imageUseCountPopUp selectedItem] tag]];
		[[self mosaic] setImageReuseDistance:[imageReuseSlider intValue]];
		[[self mosaic] setImageCropLimit:[imageCropLimitSlider intValue]];
	}

		// Let the editor free up whatever resources it was using.
	[editor editingComplete];
			
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
		
		minWidth = MAX(minWidth, 426.0);
		minHeight = MAX(minHeight, 434.0);
		
		proposedFrameSize.width = MAX(proposedFrameSize.width, minWidth);
		proposedFrameSize.height = MAX(proposedFrameSize.height, minHeight);
	}
	
    return proposedFrameSize;
}


@end
