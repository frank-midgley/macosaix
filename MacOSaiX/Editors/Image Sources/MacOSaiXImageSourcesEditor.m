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
#import "MacOSaiXImageSourcesView.h"
#import "MacOSaiXImageSourceView.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXPopUpButton.h"
#import "MacOSaiXWarningController.h"
#import "Tiles.h"

#import "NSImage+MacOSaiX.h"


@implementation MacOSaiXImageSourcesEditor


+ (NSImage *)image
{
	return [NSImage imageNamed:@"Image Sources"];
}


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
	[imageSourcesView retain];
	[imageSourcesView setMosaic:[[self mosaicView] mosaic]];
	[imageSourcesView setImageSourcesEditor:self];
	
	NSMenu			*popUpMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSEnumerator	*plugInEnumerator = [[[NSApp delegate] imageSourcePlugIns] objectEnumerator];
	Class			imageSourcePlugIn = nil;
	while (imageSourcePlugIn = [plugInEnumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:imageSourcePlugIn];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSMenuItem		*menuItem = [[[NSMenuItem alloc] initWithTitle:plugInName action:@selector(addImageSource:) keyEquivalent:@""] autorelease];
		
		[menuItem setImage:[[[imageSourcePlugIn image] copyWithLargestDimension:32] autorelease]];
		[menuItem setRepresentedObject:imageSourcePlugIn];
		[menuItem setTarget:self];
		
		[popUpMenu addItem:menuItem];
	}
	[addSourceButton setMenu:popUpMenu];
	[addSourceButton setIndicatorColor:[NSColor colorWithCalibratedWhite:0.3 alpha:1.0]];
	
	[removeSourceButton setEnabled:NO];
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Sources", @"");
}


- (void)loadImageSources
{
	NSArray	*imageSources = [[[self mosaicView] mosaic] imageSources];
	
	if ([imageSources count] == 0)
	{
		[imageSourcesScrollView setDocumentView:initialView];
		
			// Populate the matrix with the known image source types.
		NSArray			*knownPlugIns = [[NSApp delegate] imageSourcePlugIns];
		int				sourceTypeCount = [knownPlugIns count];
		
		[imageSourcesMatrix renewRows:1 columns:1];	// make sure the blank cell gets removed
		[imageSourcesMatrix renewRows:(sourceTypeCount + 1) / 2 columns:2];
		
		int				index;
		for (index = 0; index < sourceTypeCount; index++)
		{
			Class			imageSourcePlugIn = [knownPlugIns objectAtIndex:index];
			NSBundle		*plugInBundle = [NSBundle bundleForClass:imageSourcePlugIn];
			NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
			NSButtonCell	*buttonCell = [imageSourcesMatrix cellAtRow:index / 2 column:index % 2];
			
			[buttonCell setTitle:plugInName];
			[buttonCell setImage:[[[imageSourcePlugIn image] copyWithLargestDimension:32] autorelease]];
			[buttonCell setRepresentedObject:imageSourcePlugIn];
			[buttonCell setTarget:self];
			[buttonCell setAction:@selector(addImageSource:)];
		}
		
		if (sourceTypeCount % 2 == 1)
			[imageSourcesMatrix putCell:[[[NSImageCell alloc] initImageCell:nil] autorelease] atRow:sourceTypeCount / 2 column:1];
		
		[imageSourcesMatrix sizeToFit];
		
		NSRect			matrixFrame = [imageSourcesMatrix frame], 
						labelFrame = [labelTextField frame];
		
		labelFrame.origin.y = 6.0;
		[labelTextField setFrame:labelFrame];
		
		matrixFrame.origin.y = NSMaxY(labelFrame) + 10.0;
		[imageSourcesMatrix setFrame:matrixFrame];
		
		[initialView setFrame:NSMakeRect(0.0, 0.0, 
										 MAX(NSMaxX(matrixFrame), NSMaxX(labelFrame)) + 10.0, 
										 NSMaxY(matrixFrame) + 10.0)];
		
		[self updateMinimumViewSize];
	}
	else
	{
		[imageSourcesScrollView setDocumentView:imageSourcesView];
		
		NSRect	frameRect = [imageSourcesScrollView frame];
		[imageSourcesView setFrame:frameRect];
		
		[imageSourcesView updateImageSourceViews];
	}
}


- (NSSize)minimumViewSize
{
	NSSize	minSize = NSMakeSize(100.0, 100.0);
	
	if ([[[[self mosaicView] mosaic] imageSources] count] == 0)
	{
		if ([imageSourcesScrollView documentView] != initialView)
			[self loadImageSources];
		
		minSize.width = NSWidth([initialView frame]);
	}
	else
	{
		NSEnumerator			*viewEnumerator = [[imageSourcesView viewsWithVisibleEditors] objectEnumerator];
		MacOSaiXImageSourceView	*imageSourceView = nil;
		
		while (imageSourceView = [viewEnumerator nextObject])
			minSize.width = MAX(minSize.width, [imageSourceView minimumEditorSize].width);
	}
	
	return minSize;
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:0.0];
	
	[self loadImageSources];

	[removeSourceButton setEnabled:NO];
}


//- (void)imageSourceWasEdited:(id<MacOSaiXImageSource>)editedImageSource 
//		 originalImageSource:(id<MacOSaiXImageSource>)originalImageSource
//{
//	if (editedImageSource)
//	{
//		[[[self mosaicView] mosaic] removeImageSource:originalImageSource];
//		[[[self mosaicView] mosaic] addImageSource:editedImageSource];
//		
//		[imageSourcesTable reloadData];
//	}
//	
//	[originalImageSource release];
//}


- (IBAction)addImageSource:(id)sender
{
	Class	imageSourcePlugIn = nil;
	
	if ([sender isKindOfClass:[NSMenuItem class]])
		imageSourcePlugIn = [sender representedObject];
	else if ([sender isKindOfClass:[NSMatrix class]])
		imageSourcePlugIn = [[sender selectedCell] representedObject];
	
	if ([[imageSourcePlugIn dataSourceClass] conformsToProtocol:@protocol(MacOSaiXImageSource)])
	{
		id<MacOSaiXImageSource>		newSource = [[[[imageSourcePlugIn dataSourceClass] alloc] init] autorelease];
		[[[self mosaicView] mosaic] addImageSource:newSource];
		
		if ([[[[self mosaicView] mosaic] imageSources] count] == 1)
			[self loadImageSources];
		
		[[imageSourcesView viewForImageSource:newSource] setEditorVisible:YES];
		
		[self updateMinimumViewSize];
	}
}


//- (IBAction)editImageSource:(id)sender
//{
//	int	selectedRowIndex = [imageSourcesTable selectedRow];
//	
//	if (selectedRowIndex >= 0)
//	{
//		imageSourceBeingEdited = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:selectedRowIndex];
//		
//		[imageSourcesTable deselectAll:self];
//		[[imageSourcesTable enclosingScrollView] setHasVerticalScroller:NO];
//		[[imageSourcesTable enclosingScrollView] setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
//		
//		[editSourceButton setAction:@selector(showImageSources:)];
//		
//		NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//										[NSNumber numberWithFloat:NSMinY([[imageSourcesTable enclosingScrollView] frame])], @"Initial Table Min Y", 
//										[NSDate date], @"Start Date", 
//										nil];
//		animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 
//														   target:self 
//														 selector:@selector(animateTransition:) 
//														 userInfo:userInfo 
//														  repeats:YES] retain];
//	}
//}


- (void)plugInSettingsDidChange:(NSString *)changeDescription
{
	// TBD
}


//- (void)animateTransition:(NSTimer *)timer
//{
//	NSRect	selfBounds = [[self view] bounds];
//	float	bottomY = NSMaxY([addSourceButton frame]) + 10.0, 
//			initialY = [[[timer userInfo] objectForKey:@"Initial Table Min Y"] floatValue], 
//			targetY = (imageSourceBeingEdited ? NSMaxY(selfBounds) - 52.0 - 10.0 : bottomY), 
//			animationPhase = [[[timer userInfo] objectForKey:@"Start Date"] timeIntervalSinceNow] * -3.0;
//	
//	if (animationPhase > 1.0)
//		animationPhase = 1.0;
//	
//	float	currentY = initialY + (targetY - initialY) * animationPhase;
//	
//	[[imageSourcesTable enclosingScrollView] setFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, 
//																 currentY, 
//																 NSWidth(selfBounds) - 20.0, 
//																 NSHeight(selfBounds) - currentY - 10.0)];
//	
//	float	editorBoxHeight = currentY - bottomY - 10.0;
//	
//	if (imageSourceBeingEdited && !editorBox && editorBoxHeight > 24.0)
//	{
//		NSBundle	*plugInBundle = [NSBundle bundleForClass:[imageSourceBeingEdited class]];
//		NSString	*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"], 
//					*titleFormat = NSLocalizedString(@"%@ Image Source Settings", @"");
//		
//		editorBox = [[[NSBox alloc] initWithFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, bottomY, NSWidth(selfBounds) - 20.0, editorBoxHeight)] autorelease];
//		[editorBox setTitle:[NSString stringWithFormat:titleFormat, plugInName]];
//		[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
//		
//		Class	plugIn = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[imageSourceBeingEdited class]];
//		imageSourceEditor = [[[plugIn editorClass] alloc] initWithDelegate:self];
//		[editorBox setContentView:[imageSourceEditor editorView]];
//		
//		// TODO: deal with min/max editor sizes
//		
//		[[self view] addSubview:editorBox];
//	}
//	else
//		[editorBox setFrame:NSMakeRect(NSMinX(selfBounds) + 10.0, bottomY, NSWidth(selfBounds) - 20.0, editorBoxHeight)];
//	
//	[[self view] setNeedsDisplay:YES];
//	
//	if (animationPhase == 1.0)
//	{
//		// Finish the transition.
//		
//		[animationTimer invalidate];
//		[animationTimer release];
//		animationTimer = nil;
//		
//		if (imageSourceBeingEdited)
//		{
//			[imageSourcesTable reloadData];
//			
//			[imageSourceEditor editDataSource:imageSourceBeingEdited];
//			[editSourceButton setTitle:NSLocalizedString(@"Show All Sources", @"")];
//		}
//		else
//		{
//			[editorBox removeFromSuperview];
//			editorBox = nil;
//			
//			[[imageSourcesTable enclosingScrollView] setHasVerticalScroller:YES];
//			
//			[editSourceButton setTitle:NSLocalizedString(@"Edit", @"")];
//			[editSourceButton setAction:@selector(editImageSource:)];
//		}
//		
//		[editSourceButton sizeToFit];
//		[editSourceButton setFrame:NSMakeRect(NSMaxX(selfBounds) - 10.0 - NSWidth([editSourceButton frame]), 
//											  NSMinY([addSourceButton frame]), 
//											  NSWidth([editSourceButton frame]), 
//											  NSHeight([addSourceButton frame]))];
//	}
//}


//- (IBAction)showImageSources:(id)sender
//{
//	[[imageSourcesTable enclosingScrollView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
//	
//	[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
//	[editorBox setContentView:nil];
//	
//	[imageSourceEditor editingDidComplete];
//	[imageSourceEditor release];
//	
//	int	rowIndex = [[[[self mosaicView] mosaic] imageSources] indexOfObjectIdenticalTo:imageSourceBeingEdited];
//	imageSourceBeingEdited = nil;
//	
//	NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//									[NSNumber numberWithFloat:NSMinY([[imageSourcesTable enclosingScrollView] frame])], @"Initial Table Min Y", 
//									[NSDate date], @"Start Date", 
//									nil];
//	animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 
//													   target:self 
//													 selector:@selector(animateTransition:) 
//													 userInfo:userInfo 
//													  repeats:YES] retain];
//	
//	[imageSourcesTable reloadData];
//	[imageSourcesTable selectRow:rowIndex byExtendingSelection:NO];
//}


- (IBAction)removeImageSource:(id)sender
{
	if (![MacOSaiXWarningController warningIsEnabled:@"Removing Image Source"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Removing Image Source" 
												title:NSLocalizedString(@"Are you sure you wish to remove the selected image source?", @"") 
											  message:NSLocalizedString(@"Tiles that were displaying images from this source may no longer have an image.", @"") 
										 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Remove", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
//		id<MacOSaiXImageSource>	imageSource = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:[imageSourcesTable selectedRow]];
//		
//		[[[self mosaicView] mosaic] removeImageSource:imageSource];
//		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
//		
//		[imageSourcesTable reloadData];
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


//- (int)numberOfRowsInTableView:(NSTableView *)tableView
//{
//	if (animationTimer || !imageSourceBeingEdited)
//		return [[[[self mosaicView] mosaic] imageSources] count];
//	else
//		return 1;
//}
//
//
//- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
//{
//	id						value = nil;
//	id<MacOSaiXImageSource>	imageSource = nil;
//	
//	if (animationTimer || !imageSourceBeingEdited)
//		imageSource = [[[[self mosaicView] mosaic] imageSources] objectAtIndex:row];
//	else
//		imageSource = imageSourceBeingEdited;
//	
//	if ([[tableColumn identifier] isEqualToString:@"Image"])
//		value = [imageSource image];
//	else if ([[tableColumn identifier] isEqualToString:@"Description"])
//		value = [imageSource briefDescription];
//	else if ([[tableColumn identifier] isEqualToString:@"Image Count"])
//		value = [NSNumber numberWithUnsignedLong:[[[self mosaicView] mosaic] countOfImagesFromSource:imageSource]];
//	
//	return value;
//}
//
//
//- (void)tableViewSelectionDidChange:(NSNotification *)notification
//{
//	if (imageSourceBeingEdited)
//		[imageSourcesTable deselectAll:self];
//	else
//	{
//		[highlightedImageSourcesLock lock];
//		
//			[highlightedImageSources release];
//			highlightedImageSources = [[NSMutableArray alloc] initWithCapacity:16];
//			
//			NSEnumerator	*indexEnumerator = [imageSourcesTable selectedRowEnumerator];
//			NSNumber		*index = nil;
//			
//			while (index = [indexEnumerator nextObject])
//				[highlightedImageSources addObject:[[[[self mosaicView] mosaic] imageSources] objectAtIndex:[index intValue]]];
//			
//			if (highlightedImageSourcesOutline)
//				[[self mosaicView] setNeedsDisplay:YES];
//			
//			[highlightedImageSourcesOutline release];
//			highlightedImageSourcesOutline = nil;
//			
//				// Create a combined path for all tiles of our document that are not currently displaying an image from any of the sources.
//			if ([highlightedImageSources count] > 0)
//				[self createHighlightedImageSourcesOutline];
//			
//			if (highlightedImageSourcesOutline)
//				[[self mosaicView] setNeedsDisplay:YES];
//		
//		[highlightedImageSourcesLock unlock];
//		
//		[removeSourceButton setEnabled:([highlightedImageSources count] > 0)];
//		[editSourceButton setEnabled:([highlightedImageSources count] > 0)];
//	}
//}


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


- (void)imageSourcesSelectionDidChange
{
	[removeSourceButton setEnabled:([[imageSourcesView selectedImageSources] count] > 0)];
}


- (void)endEditing
{
	[removeSourceButton setEnabled:NO];
	
	[super endEditing];
}


- (void)dealloc
{
	[imageSourcesView release];
	[highlightedImageSources release];
	[highlightedImageSourcesLock release];
	[highlightedImageSourcesOutline release];
	
	[super dealloc];
}


@end
