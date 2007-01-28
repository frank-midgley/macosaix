//
//  MacOSaiXTargetImageEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourcesEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXPopUpButton.h"
#import "MacOSaiXWarningController.h"
#import "Tiles.h"


@implementation MacOSaiXImageSourcesEditor


- (id)initWithMosaic:(MosaicView *)inMosaicView
{
	if (self = [super initWithMosaicView:inMosaicView])
	{
		highlightedImageSourcesLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Image Sources Editor";
}


- (void)awakeFromNib
{
	[imageSourcesTable setTarget:self];
	[imageSourcesTable setDoubleAction:@selector(editImageSource:)];
	[addSourceButton setIndicatorColor:[NSColor colorWithCalibratedWhite:0.2941 alpha:1.0]];
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Sources", @"");
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:0.0];
	
		// Populate the "Add" button with the current list of image source types.
	NSEnumerator	*enumerator = [[[NSApp delegate] imageSourcePlugIns] objectEnumerator];
	Class			imageSourcePlugIn = nil;
	[addSourceButton removeAllItems];
	while (imageSourcePlugIn = [enumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:imageSourcePlugIn];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		[addSourceButton addItemWithTitle:[NSString stringWithFormat:@"%@...", plugInName]];
		[[addSourceButton lastItem] setRepresentedObject:imageSourcePlugIn];
		
		NSImage			*image = [[[imageSourcePlugIn image] copy] autorelease];
		[image setScalesWhenResized:YES];
		if ([image size].width > [image size].height)
			[image setSize:NSMakeSize(16.0, 16.0 * [image size].height / [image size].width)];
		else
			[image setSize:NSMakeSize(16.0 * [image size].width / [image size].height, 16.0)];
		[image lockFocus];	// force the image to be scaled
		[image unlockFocus];
		[[addSourceButton lastItem] setImage:image];
	}
}


- (void)imageSourceWasEdited:(id<MacOSaiXImageSource>)editedImageSource 
		 originalImageSource:(id<MacOSaiXImageSource>)originalImageSource
{
	if (editedImageSource)
	{
		[[[self mosaicView] mosaic] removeImageSource:originalImageSource];
		[[[self mosaicView] mosaic] addImageSource:editedImageSource];
		
		[imageSourcesTable reloadData];
	}
	
	[originalImageSource release];
}


- (IBAction)addImageSource:(id)sender
{
	Class	imageSourcePlugIn = nil;
	
	if ([sender isKindOfClass:[NSMenuItem class]])
		imageSourcePlugIn = [sender representedObject];
	else if ([sender isKindOfClass:[NSPopUpButton class]])
		imageSourcePlugIn = [[sender selectedItem] representedObject];
	
	if ([[imageSourcePlugIn dataSourceClass] conformsToProtocol:@protocol(MacOSaiXImageSource)])
	{
		id<MacOSaiXImageSource>		newSource = [[[[imageSourcePlugIn dataSourceClass] alloc] init] autorelease];
		[[[self mosaicView] mosaic] addImageSource:newSource];
		[imageSourcesTable reloadData];
		[imageSourcesTable selectRow:([[[[self mosaicView] mosaic] imageSources] count] - 1) byExtendingSelection:NO];
		[self editImageSource:self];
	}
}


- (IBAction)editImageSource:(id)sender
{
	int	selectedRowIndex = [imageSourcesTable selectedRow];
	
	if (selectedRowIndex >= 0)
	{
		imageSourceBeingEdited = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:selectedRowIndex];
		
		[imageSourcesTable deselectAll:self];
		[[imageSourcesTable enclosingScrollView] setHasVerticalScroller:NO];
		[[imageSourcesTable enclosingScrollView] setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
		
		[editSourceButton setAction:@selector(showImageSources:)];
		
		NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithFloat:NSMinY([[imageSourcesTable enclosingScrollView] frame])], @"Initial Table Min Y", 
										[NSDate date], @"Start Date", 
										nil];
		animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 
														   target:self 
														 selector:@selector(animateTransition:) 
														 userInfo:userInfo 
														  repeats:YES] retain];
	}
}


- (NSImage *)targetImage
{
	return [[[self mosaicView] mosaic] targetImage];
}


- (void)plugInSettingsDidChange:(NSString *)changeDescription
{
	// TBD
}


- (void)animateTransition:(NSTimer *)timer
{
	NSRect	selfBounds = [[self view] bounds];
	float	bottomY = NSMaxY([addSourceButton frame]) + 10.0, 
			initialY = [[[timer userInfo] objectForKey:@"Initial Table Min Y"] floatValue], 
			targetY = (imageSourceBeingEdited ? NSMaxY(selfBounds) - 52.0 - 10.0 : bottomY), 
			animationPhase = [[[timer userInfo] objectForKey:@"Start Date"] timeIntervalSinceNow] * -3.0;
	
	if (animationPhase > 1.0)
		animationPhase = 1.0;
	
	float	currentY = initialY + (targetY - initialY) * animationPhase;
	
	[[imageSourcesTable enclosingScrollView] setFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, 
																 currentY, 
																 NSWidth(selfBounds) - 20.0, 
																 NSHeight(selfBounds) - currentY - 10.0)];
	
	float	editorBoxHeight = currentY - bottomY - 10.0;
	
	if (imageSourceBeingEdited && !editorBox && editorBoxHeight > 24.0)
	{
		NSBundle	*plugInBundle = [NSBundle bundleForClass:[imageSourceBeingEdited class]];
		NSString	*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"], 
					*titleFormat = NSLocalizedString(@"%@ Image Source Settings", @"");
		
		editorBox = [[[NSBox alloc] initWithFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, bottomY, NSWidth(selfBounds) - 20.0, editorBoxHeight)] autorelease];
		[editorBox setTitle:[NSString stringWithFormat:titleFormat, plugInName]];
		[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		
		Class	plugIn = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[imageSourceBeingEdited class]];
		imageSourceEditor = [[[plugIn dataSourceEditorClass] alloc] initWithDelegate:self];
		[editorBox setContentView:[imageSourceEditor editorView]];
		
		// TODO: deal with min/max editor sizes
		
		[[self view] addSubview:editorBox];
	}
	else
		[editorBox setFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, bottomY, NSWidth(selfBounds) - 20.0, editorBoxHeight)];
	
	[[self view] setNeedsDisplay:YES];
	
	if (animationPhase == 1.0)
	{
		// Finish the transition.
		
		[animationTimer invalidate];
		[animationTimer release];
		animationTimer = nil;
		
		if (imageSourceBeingEdited)
		{
			[imageSourcesTable reloadData];
			
			[imageSourceEditor editDataSource:imageSourceBeingEdited];
			[editSourceButton setTitle:NSLocalizedString(@"Show All Sources", @"")];
		}
		else
		{
			[editorBox removeFromSuperview];
			editorBox = nil;
			
			[[imageSourcesTable enclosingScrollView] setHasVerticalScroller:YES];
			
			[editSourceButton setTitle:NSLocalizedString(@"Edit", @"")];
			[editSourceButton setAction:@selector(editImageSource:)];
		}
		
		[editSourceButton sizeToFit];
		[editSourceButton setFrame:NSMakeRect(NSMaxX(selfBounds) - 10.0 - NSWidth([editSourceButton frame]), 
											  NSMinY([addSourceButton frame]), 
											  NSWidth([editSourceButton frame]), 
											  NSHeight([addSourceButton frame]))];
	}
}


- (IBAction)showImageSources:(id)sender
{
	[[imageSourcesTable enclosingScrollView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	
	[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
	[editorBox setContentView:nil];
	
	[imageSourceEditor editingDidComplete];
	[imageSourceEditor release];
	
	int	rowIndex = [[[[self mosaicView] mosaic] imageSources] indexOfObjectIdenticalTo:imageSourceBeingEdited];
	imageSourceBeingEdited = nil;
	
	NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithFloat:NSMinY([[imageSourcesTable enclosingScrollView] frame])], @"Initial Table Min Y", 
									[NSDate date], @"Start Date", 
									nil];
	animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 
													   target:self 
													 selector:@selector(animateTransition:) 
													 userInfo:userInfo 
													  repeats:YES] retain];
	
	[imageSourcesTable reloadData];
	[imageSourcesTable selectRow:rowIndex byExtendingSelection:NO];
}


- (IBAction)removeImageSource:(id)sender
{
	if (![MacOSaiXWarningController warningIsEnabled:@"Removing Image Source"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Removing Image Source" 
												title:NSLocalizedString(@"Are you sure you wish to remove the selected image source?", @"") 
											  message:NSLocalizedString(@"Tiles that were displaying images from this source may no longer have an image.", @"") 
										 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Remove", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		id<MacOSaiXImageSource>	imageSource = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:[imageSourcesTable selectedRow]];
		
		[[[self mosaicView] mosaic] removeImageSource:imageSource];
		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
		
		[imageSourcesTable reloadData];
	}
}


- (void)createHighlightedImageSourcesOutline
{
	NSEnumerator	*tileEnumerator = [[[[self mosaicView] mosaic] tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	displayedSource = [[tile userChosenImageMatch] imageSource];
		if (!displayedSource)
			displayedSource = [[tile uniqueImageMatch] imageSource];
		
		if (displayedSource && [highlightedImageSources containsObject:displayedSource])
		{
			if (!highlightedImageSourcesOutline)
				highlightedImageSourcesOutline = [[NSBezierPath bezierPath] retain];
			[highlightedImageSourcesOutline appendBezierPath:[tile outline]];
		}
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (animationTimer || !imageSourceBeingEdited)
		return [[[[self mosaicView] mosaic] imageSources] count];
	else
		return 1;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id						value = nil;
	id<MacOSaiXImageSource>	imageSource = nil;
	
	if (animationTimer || !imageSourceBeingEdited)
		imageSource = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:row];
	else
		imageSource = imageSourceBeingEdited;
	
	if ([[tableColumn identifier] isEqualToString:@"Image"])
		value = [imageSource image];
	else if ([[tableColumn identifier] isEqualToString:@"Description"])
		value = [imageSource briefDescription];
	else if ([[tableColumn identifier] isEqualToString:@"Image Count"])
		value = [NSNumber numberWithUnsignedLong:[[[self mosaicView] mosaic] countOfImagesFromSource:imageSource]];
	
	return value;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if (imageSourceBeingEdited)
		[imageSourcesTable deselectAll:self];
	else
	{
		[highlightedImageSourcesLock lock];
		
			[highlightedImageSources release];
			highlightedImageSources = [[NSMutableArray alloc] initWithCapacity:16];
			
			NSEnumerator	*indexEnumerator = [imageSourcesTable selectedRowEnumerator];
			NSNumber		*index = nil;
			
			while (index = [indexEnumerator nextObject])
				[highlightedImageSources addObject:[[[[self mosaicView] mosaic] imageSources] objectAtIndex:[index intValue]]];
			
			if (highlightedImageSourcesOutline)
				[[self mosaicView] setNeedsDisplay:YES];
			
			[highlightedImageSourcesOutline release];
			highlightedImageSourcesOutline = nil;
			
				// Create a combined path for all tiles of our document that are not currently displaying an image from any of the sources.
			if ([highlightedImageSources count] > 0)
				[self createHighlightedImageSourcesOutline];
			
			if (highlightedImageSourcesOutline)
				[[self mosaicView] setNeedsDisplay:YES];
		
		[highlightedImageSourcesLock unlock];
		
		[removeSourceButton setEnabled:([highlightedImageSources count] > 0)];
		[editSourceButton setEnabled:([highlightedImageSources count] > 0)];
	}
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
	[super embellishMosaicViewInRect:rect];
	
		// Highlight the selected image source(s).
	[highlightedImageSourcesLock lock];
		if (highlightedImageSourcesOutline)
		{
			NSSize				boundsSize = [[self mosaicView] imageBounds].size;
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:0.5 yBy:0.5];
			[transform scaleXBy:boundsSize.width yBy:boundsSize.height];
			NSBezierPath		*transformedOutline = [transform transformBezierPath:highlightedImageSourcesOutline];
			
				// Lighten the tiles not displaying images from the highlighted image sources.
			NSBezierPath		*lightenOutline = [NSBezierPath bezierPath];
			[lightenOutline moveToPoint:NSMakePoint(0, 0)];
			[lightenOutline lineToPoint:NSMakePoint(0, boundsSize.height)];
			[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, boundsSize.height)];
			[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, 0)];
			[lightenOutline closePath];
			[lightenOutline appendBezierPath:transformedOutline];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
			[lightenOutline fill];
			
				// Darken the outline of the tile.
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
			[transformedOutline stroke];
		}
	[highlightedImageSourcesLock unlock];
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
}


- (void)dealloc
{
	[highlightedImageSources release];
	[highlightedImageSourcesLock release];
	[highlightedImageSourcesOutline release];
	
	[super dealloc];
}


@end
