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


NSComparisonResult compareDisplayedMatchValue(id tileDict1, id tileDict2, void *context)
{
	MacOSaiXImageMatch	*thisMatch = [[tileDict1 objectForKey:@"Tile"] displayedImageMatch], 
						*otherMatch = [[tileDict2 objectForKey:@"Tile"] displayedImageMatch];
	float				thisValue = (thisMatch ? [thisMatch matchValue] : MAXFLOAT), 
						otherValue = (otherMatch ? [otherMatch matchValue] : MAXFLOAT);
	
	if (thisValue == otherValue)
		return NSOrderedSame;
	else if (thisValue < otherValue)
		return NSOrderedAscending;
	else
		return NSOrderedDescending;
}


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
		{
			[tilesToRefresh addObject:[notification userInfo]];
			[tilesToRefresh sortUsingFunction:compareDisplayedMatchValue context:nil];
		}
		
		if (!refreshTilesTimer)
			[self performSelectorOnMainThread:@selector(startTileRefreshTimer) withObject:nil waitUntilDone:NO];
	[tileRefreshLock unlock];
}


- (void)startTileRefreshTimer
{
	[tileRefreshLock lock];
		if (!refreshTilesTimer && [tilesToRefresh count] > 0)
			refreshTilesTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5 
																  target:self 
															    selector:@selector(spawnRefreshThread:) 
															    userInfo:nil 
																 repeats:NO] retain];
	[tileRefreshLock unlock];
}


- (void)spawnRefreshThread:(NSTimer *)timer
{
	[tileRefreshLock lock];
			// Spawn a thread to refresh all tiles whose images have changed.
		if (!refreshTileThreadRunning)
		{
			refreshTileThreadRunning = YES;
			[NSApplication detachDrawingThread:@selector(refreshTiles) toTarget:self withObject:nil];
		}
		
		[refreshTilesTimer autorelease];
		refreshTilesTimer = nil;
	[tileRefreshLock unlock];
}


- (void)refreshTiles
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSDictionary		*tileToRefresh = nil;
	
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
	
	refreshTileThreadRunning = NO;
	
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
				transitionWidth = 0.0, 
				matrixWidth = floorf(24.0 * (windowHeight - transitionHeight) / 21.0 / 6.0) * 6.0, 
				matrixHeight = floorf(matrixWidth / 6.0 / 4.0 * 3.0 + 0.5), 
				settingsWidth = windowWidth - matrixWidth, 
				mosaicHeight = windowHeight - matrixHeight - transitionHeight;
	
	if (settingsWidth > 180.0 + 64.0)
	{
		transitionWidth = 64.0;
		settingsWidth -= 64.0;
	}
	else if (settingsWidth > 180.0)
	{
		transitionWidth = settingsWidth - 180.0;
		settingsWidth = 180.0;
	}
	
		// Position the original image matrix in the upper left corner of the window.
	[originalImageMatrix setCellSize:NSMakeSize(matrixWidth / 6.0, matrixHeight)];
	[originalImageMatrix setFrame:NSMakeRect(0.0, mosaicHeight + transitionHeight, matrixWidth, matrixHeight)];
	
		// Position the custom text field in the upper right corner of the window.
	[customTextField setFrame:NSMakeRect(matrixWidth + transitionWidth, mosaicHeight + transitionHeight, 
										 settingsWidth, matrixHeight)];
	
		// Position the mosaic view in the lower left corner of the window.
	[mosaicView setFrame:NSMakeRect(0.0, 0.0, matrixWidth, mosaicHeight)];
	
		// Position the image sources view in the lower right corner of the window.
	[imageSourcesView setFrame:NSMakeRect(matrixWidth + transitionWidth, 0.0, settingsWidth, mosaicHeight)];
	
		// Center the vanity view between the custom text field and the image sources view and 
		// against the right edge of the window.
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
