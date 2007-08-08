//
//  MacOSaiXTargetImageEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourcesEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXEnumeratedImage.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatch.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXImageSourcesView.h"
#import "MacOSaiXImageSourceView.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXPopUpButton.h"
#import "MacOSaiXSourceImage.h"
#import "MacOSaiXWarningController.h"
#import "Tiles.h"

#import "NSImage+MacOSaiX.h"


@implementation MacOSaiXImageSourcesEditor


+ (void)load
{
	[super load];
}


+ (NSImage *)image
{
	return [NSImage imageNamed:@"Image Sources"];
}


+ (NSString *)title
{
	return NSLocalizedString(@"Image Sources", @"");
}


+ (NSString *)description
{
	return NSLocalizedString(@"This setting lets you choose where to get the images to fill into the tiles.", @"");
}


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
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
	[imageSourcesView setMosaic:[[self delegate] mosaic]];
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


- (NSImage *)targetImage
{
	return [[[self delegate] mosaic] targetImage];
}


- (void)loadImageSources
{
	if ([[[[self delegate] mosaic] imageSourceEnumerators] count] == 0)
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
	
	if ([[[[self delegate] mosaic] imageSourceEnumerators] count] == 0)
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
	[super beginEditing];
	
	[self loadImageSources];

	[removeSourceButton setEnabled:NO];
}


- (IBAction)addImageSource:(id)sender
{
	if (![self isActive])
	{
		if ([[self delegate] setActiveEditor:self])
			[self performSelector:_cmd withObject:sender afterDelay:0.0];
	}
	else
	{
		Class	imageSourcePlugIn = nil;
		
		if ([sender isKindOfClass:[NSMenuItem class]])
			imageSourcePlugIn = [sender representedObject];
		else if ([sender isKindOfClass:[NSMatrix class]])
			imageSourcePlugIn = [[sender selectedCell] representedObject];
		
		if ([[imageSourcePlugIn dataSourceClass] conformsToProtocol:@protocol(MacOSaiXImageSource)])
		{
			id<MacOSaiXImageSource>		newSource = [[[[imageSourcePlugIn dataSourceClass] alloc] init] autorelease];
			[[[self delegate] mosaic] addImageSource:newSource];
			
			if ([[[[self delegate] mosaic] imageSourceEnumerators] count] == 1)
				[self loadImageSources];
			
			MacOSaiXImageSourceView		*imageSourceView = [imageSourcesView viewForImageSource:newSource];
			[imageSourceView setEditor:self];
			[imageSourceView setEditorVisible:YES];
			
			[self updateMinimumViewSize];
		}
	}
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource 
	  didChangeKey:(NSString *)key
		 fromValue:(id)previousValue 
		actionName:(NSString *)actionName;
{
	[super dataSource:dataSource didChangeKey:key fromValue:previousValue actionName:actionName];
	
	[[[self delegate] mosaic] imageSourceDidChange:(id<MacOSaiXImageSource>)dataSource];
}


- (IBAction)removeImageSource:(id)sender
{
	if (![MacOSaiXWarningController warningIsEnabled:@"Removing Image Source"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Removing Image Source" 
												title:NSLocalizedString(@"Are you sure you wish to remove the selected image sources?", @"") 
											  message:NSLocalizedString(@"Tiles that were displaying images from these sources may no longer have an image.", @"") 
										 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Remove", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		MacOSaiXMosaic			*mosaic = [[self delegate] mosaic];
		
		BOOL					wasRunning = ![mosaic isPaused];
		if (wasRunning)
			[mosaic pause];
		
		NSEnumerator					*imageSourceEnumeratorEnumerator = [[imageSourcesView selectedImageSourceEnumerators] objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
		while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
			[mosaic removeImageSource:[imageSourceEnumerator imageSource]];
		
		if ([[mosaic imageSourceEnumerators] count] == 0)
			[self loadImageSources];
		
		[removeSourceButton setEnabled:NO];
		
		if (wasRunning)
			[mosaic resume];
	}
}


- (void)createHighlightedImageSourcesOutline
{
	NSEnumerator	*tileEnumerator = [[[[self delegate] mosaic] tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	displayedSource = [[(MacOSaiXEnumeratedImage *)[[tile userChosenImageMatch] sourceImage] enumerator] imageSource];
		if (!displayedSource)
			displayedSource = [[(MacOSaiXEnumeratedImage *)[[tile uniqueImageMatch] sourceImage] enumerator] imageSource];
		
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
//		return [[[[self delegate] mosaic] imageSources] count];
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
//		imageSource = [[[[self delegate] mosaic] imageSources] objectAtIndex:row];
//	else
//		imageSource = imageSourceBeingEdited;
//	
//	if ([[tableColumn identifier] isEqualToString:@"Image"])
//		value = [imageSource image];
//	else if ([[tableColumn identifier] isEqualToString:@"Description"])
//		value = [imageSource briefDescription];
//	else if ([[tableColumn identifier] isEqualToString:@"Image Count"])
//		value = [NSNumber numberWithUnsignedLong:[[[self delegate] mosaic] countOfImagesFromSource:imageSource]];
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
//				[highlightedImageSources addObject:[[[[self delegate] mosaic] imageSources] objectAtIndex:[index intValue]]];
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


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	[super embellishMosaicView:mosaicView inRect:rect];
	
		// Highlight the selected image source(s).
	[highlightedImageSourcesLock lock];
		if (highlightedImageSourcesOutline)
		{
			NSSize				boundsSize = [mosaicView imageBounds].size;
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


- (void)imageSourcesSelectionDidChange
{
	[removeSourceButton setEnabled:([[imageSourcesView selectedImageSourceEnumerators] count] > 0)];
}


- (BOOL)endEditing
{
	if ([super endEditing])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[[self delegate] mosaic]];
		
		[removeSourceButton setEnabled:NO];
		
		return YES;
	}
	else
		return NO;
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
