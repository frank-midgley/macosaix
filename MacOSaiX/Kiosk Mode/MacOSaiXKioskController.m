//
//  MacOSaiXKioskController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskController.h"

#import "GoogleImageSource.h"
#import "RectangularTileShapes.h"

#import <pthread.h>


#define MAX_REFRESH_THREAD_COUNT 1


@implementation MacOSaiXKioskController


- (NSString *)windowNibName
{
	return @"Kiosk";
}


- (void)awakeFromNib
{
		// Populate the original image buttons
	originalImages = [[NSMutableArray arrayWithObjects:[NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], nil] retain];
	NSArray			*originalImagePaths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"];
	int				column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [originalImagePaths count] ? [originalImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			[originalImages replaceObjectAtIndex:column withObject:image];
			[buttonCell setTitle:imagePath];
			[buttonCell setImagePosition:NSImageOnly];
			[image release];
		}
		else
		{
			[buttonCell setTitle:@"No Image Available"];
			[buttonCell setImage:nil];
			[buttonCell setImagePosition:NSNoImage];
		}
	}
	
	MacOSaiXRectangularTileShapes	*tileShapes = [[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init];
	[tileShapes setTilesAcross:50];
	[tileShapes setTilesDown:50];
	
	mosaic = [[MacOSaiXMosaic alloc] init];
	[mosaic setOriginalImage:[originalImages objectAtIndex:0]];
	[mosaic setTileShapes:tileShapes creatingTiles:YES];
	[mosaic setImageUseCount:0];
	[mosaic setImageReuseDistance:10];
	[mosaic setImageCropLimit:25];
	
	[mosaicView setMosaic:mosaic];
	[mosaicView setViewFade:1.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(mosaicDidChangeState:) 
												 name:MacOSaiXMosaicDidChangeStateNotification 
											   object:mosaic];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileImageDidChangeNotification 
											   object:mosaic];
	tileRefreshLock = [[NSLock alloc] init];
	tilesToRefresh = [[NSMutableArray array] retain];
	
	[mosaic resume];
}


- (IBAction)setOriginalImage:(id)sender
{
	[mosaic setOriginalImage:[originalImages objectAtIndex:[originalImageMatrix selectedColumn]]];
	[kioskView setNeedsDisplayInRect:NSMakeRect(NSMinX([mosaicView frame]), 
														NSMaxY([mosaicView frame]), 
														NSWidth([mosaicView frame]), 
														NSMinY([originalImageMatrix frame]) - 
															NSMaxY([mosaicView frame]))];
}


- (IBAction)addKeyword:(id)sender
{
	GoogleImageSource	*newSource = [[NSClassFromString(@"GoogleImageSource") alloc] init];
	
	[newSource setAdultContentFiltering:strictFiltering];
	[newSource setRequiredTerms:[keywordTextField stringValue]];
	
	[mosaic addImageSource:newSource];
	
	[newSource release];
}


- (IBAction)removeKeyword:(id)sender
{
	// TODO
}


#pragma mark


- (void)mosaicDidChangeState:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:notification waitUntilDone:NO];
	else
	{
		[imageSourcesTableView reloadData];
	}
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	[tileRefreshLock lock];
		if ([tilesToRefresh indexOfObject:[notification userInfo]] == NSNotFound)
			[tilesToRefresh addObject:[notification userInfo]];
		
		if (refreshTilesThreadCount == 0)
			[NSApplication detachDrawingThread:@selector(refreshTiles:) toTarget:self withObject:nil];
	[tileRefreshLock unlock];
}


- (void)refreshTiles:(id)dummy
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSDictionary		*tileToRefresh = nil;

        // Make sure only one copy of this thread runs at any time.
	[tileRefreshLock lock];
		if (refreshTilesThreadCount >= MAX_REFRESH_THREAD_COUNT)
		{
                // Not allowed to run any more threads, just exit.
			[tileRefreshLock unlock];
			[pool release];
			return;
		}
		refreshTilesThreadCount++;
	[tileRefreshLock unlock];
	
	do
	{
		NSAutoreleasePool	*innerPool = [[NSAutoreleasePool alloc] init];
		
		tileToRefresh = nil;
		[tileRefreshLock lock];
			if ([tilesToRefresh count] > 0)
			{
				tileToRefresh = [[[tilesToRefresh objectAtIndex:0] retain] autorelease];
				[tilesToRefresh removeObjectAtIndex:0];
			}
		[tileRefreshLock unlock];
		
		if (tileToRefresh)
			[mosaicView refreshTile:[tileToRefresh objectForKey:@"Tile"] 
					  previousMatch:[tileToRefresh objectForKey:@"Previous Match"]];
		
		[innerPool release];
	} while (tileToRefresh);
	
	[tileRefreshLock lock];
		refreshTilesThreadCount--;
	[tileRefreshLock unlock];
	
	[pool release];
}


#pragma mark


- (void)windowDidResize:(NSNotification *)notification
{
		// Resize all of the views so that the original images and the mosaic maintain a 4x3 aspect ratio.
	NSWindow	*window = [notification object];
	float		windowHeight = NSHeight([window frame]), 
				windowWidth = NSWidth([window frame]), 
				transitionHeight = 64.0, 
				matrixWidth = floorf(24.0 * (windowHeight - transitionHeight) / 21.0 / 6.0) * 6.0, 
				matrixHeight = floorf(matrixWidth / 6.0 / 4.0 * 3.0 + 0.5), 
				settingsWidth = windowWidth - matrixWidth, 
				mosaicHeight = windowHeight - matrixHeight - transitionHeight;
	
	[originalImageMatrix setCellSize:NSMakeSize(matrixWidth / 6.0, matrixHeight)];
	[originalImageMatrix setFrame:NSMakeRect(0.0, mosaicHeight + transitionHeight, matrixWidth, matrixHeight)];
	[customTextField setFrame:NSInsetRect(NSMakeRect(matrixWidth, mosaicHeight + transitionHeight, settingsWidth, matrixHeight), 4.0, 4.0)];
	[mosaicView setFrame:NSMakeRect(0.0, 0.0, matrixWidth, mosaicHeight)];
	[imageSourcesView setFrame:NSMakeRect(matrixWidth, 0.0, settingsWidth, mosaicHeight)];
	
	NSSize		vanitySize = [vanityView frame].size;
	[vanityView setFrameOrigin:NSMakePoint(windowWidth - vanitySize.width - 4.0, 
										   mosaicHeight + (transitionHeight - vanitySize.height) / 2.0)];
	
		// Populate the original image buttons now that we know what size they are.
	int		column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		
		if ([buttonCell imagePosition] == NSImageOnly)
		{
			NSImage	*image = [[originalImages objectAtIndex:column] copy];
			
			[image setScalesWhenResized:YES];
			[image setSize:[originalImageMatrix cellSize]];
			[buttonCell setAlternateImage:image];
			
			NSImage	*darkenedImage = [image copy];
			[darkenedImage lockFocus];
				[[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] set];
				[[NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)] fill];
			[darkenedImage unlockFocus];
			[buttonCell setImage:darkenedImage];
			
			[image release];
			[darkenedImage release];
		}
	}
}


#pragma mark -
#pragma mark Table delegate methods


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == imageSourcesTableView)
		return [[mosaic imageSources] count];
	
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	id	objectValue = nil;
	
    if (tableView == imageSourcesTableView)
    {
		id<MacOSaiXImageSource>	imageSource = [[mosaic imageSources] objectAtIndex:rowIndex];
		
		if ([[tableColumn identifier] isEqualToString:@"Count"])
			return [NSNumber numberWithUnsignedLong:[mosaic countOfImagesFromSource:imageSource]];
		else
			objectValue = [imageSource descriptor];
    }

	return objectValue;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == imageSourcesTableView)
	{
		NSMutableArray	*selectedImageSources = [NSMutableArray array];
		NSEnumerator	*selectedRowNumberEnumerator = [imageSourcesTableView selectedRowEnumerator];
		NSNumber		*selectedRowNumber = nil;
		while (selectedRowNumber = [selectedRowNumberEnumerator nextObject])
		{
			int	rowIndex = [selectedRowNumber intValue];
			[selectedImageSources addObject:[[mosaic imageSources] objectAtIndex:rowIndex]];
		}
		
		[removeKeywordButton setEnabled:([selectedImageSources count] > 0)];
		
//		if ([[mosaic imageSources] count] > 1)
//			[mosaicView highlightImageSources:selectedImageSources];
//		else
//			[mosaicView highlightImageSources:nil];
	}
}


#pragma mark


- (void)dealloc
{
	[originalImages release];
	
	[super dealloc];
}


@end
