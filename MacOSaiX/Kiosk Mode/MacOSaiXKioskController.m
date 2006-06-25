//
//  MacOSaiXKioskController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskController.h"

#import "GoogleImageSource.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXFullScreenController.h"
#import "MacOSaiXKioskMessageView.h"
#import "MacOSaiXKioskView.h"
#import "MacOSaiXMosaic.h"
#import "MosaicView.h"
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


@interface MacOSaiXDocument (PrivateMethods)
- (void)threadedSaveWithParameters:(NSDictionary *)parameters;
@end


@implementation MacOSaiXKioskController


- (id)initWithWindow:(NSWindow *)window
{
	if (self = [super initWithWindow:window])
	{
		mosaics = [[NSMutableArray arrayWithObjects:[NSNull null], [NSNull null], [NSNull null], 
													[NSNull null], [NSNull null], [NSNull null], nil] retain];
		mosaicControllers = [[NSMutableArray array] retain];
	}
	
	return self;
}


- (NSString *)windowNibName
{
	return @"Kiosk";
}


- (void)setMosaicControllers:(NSArray *)controllers
{
	[mosaicControllers removeAllObjects];
	[mosaicControllers addObjectsFromArray:controllers];
	
		// Tell all of the "mosaic only" windows to show this mosaic.
	NSEnumerator					*controllerEnumerator = [mosaicControllers objectEnumerator];
	MacOSaiXFullScreenController	*controller = nil;
	while (controller = [controllerEnumerator nextObject])
		[controller setMosaic:currentMosaic];
}


- (void)useMosaicAtIndex:(int)index
{
	{
			// Stop the previous mosaic.
		[currentMosaic pause];
		
		if ([[currentMosaic imageSources] count] > 0)
		{
				// Save the current mosaic for posterity.
			NSString			*saveFilePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]
																	stringByAppendingPathComponent:@"Kiosk Mosaics"];
			if (![[NSFileManager defaultManager] fileExistsAtPath:saveFilePath])
				[[NSFileManager defaultManager] createDirectoryAtPath:saveFilePath attributes:nil];
			saveFilePath = [[saveFilePath stringByAppendingPathComponent:[[NSDate date] description]]
											stringByAppendingPathExtension:@"mosaic"];
			MacOSaiXDocument	*tempDocument = [[MacOSaiXDocument alloc] init];
			[tempDocument setMosaic:currentMosaic];
			int					currentIndex = [mosaics indexOfObjectIdenticalTo:currentMosaic];
			[tempDocument setOriginalImagePath:[[originalImageMatrix cellAtRow:0 column:currentIndex] title]];
			[tempDocument threadedSaveWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
														saveFilePath, @"Save Path", 
														[NSNumber numberWithBool:YES], @"Was Paused", 
														nil]];
			[tempDocument release];
		}
		
			// Remove all of the image sources.
		NSEnumerator			*imageSourceEnumerator = [[currentMosaic imageSources] objectEnumerator];
		id<MacOSaiXImageSource>	imageSource = nil;
		while (imageSource = [imageSourceEnumerator nextObject])
			[currentMosaic removeImageSource:imageSource];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:MacOSaiXMosaicDidChangeStateNotification 
													  object:currentMosaic];
	}
	
	{
			// Switch to the new mosaic
		currentMosaic = [mosaics objectAtIndex:index];
		
		[mosaicView setMosaic:currentMosaic];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeStateNotification 
												   object:currentMosaic];
		
			// Tell all of the "mosaic only" windows to show this mosaic.
		NSEnumerator					*controllerEnumerator = [mosaicControllers objectEnumerator];
		MacOSaiXFullScreenController	*controller = nil;
		while (controller = [controllerEnumerator nextObject])
			[controller setMosaic:currentMosaic];
		
//		[keywordTextField setStringValue:@"mosaic"];
//		[self addKeyword:self];
		
		[currentMosaic resume];
	}
}


- (void)awakeFromNib
{
		// Populate the original image buttons
	NSArray			*originalImagePaths = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Kiosk Settings"]
																				  objectForKey:@"Original Image Paths"];
	int				column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [originalImagePaths count] ? [originalImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			MacOSaiXMosaic	*mosaic = [[MacOSaiXMosaic alloc] init];
			[mosaic setOriginalImage:image];
			[mosaic setImageUseCount:0];
			[mosaic setImageReuseDistance:10];
			[mosaic setImageCropLimit:25];
			[mosaics replaceObjectAtIndex:column withObject:mosaic];
			[mosaic release];
			
			[buttonCell setTitle:imagePath];
			[buttonCell setImagePosition:NSImageOnly];
			[image release];
		}
		else
		{
			[buttonCell setTitle:NSLocalizedString(@"No Image Available", @"")];
			[buttonCell setImage:nil];
			[buttonCell setImagePosition:NSNoImage];
		}
	}
	
	[messageView setEditable:NO];
	
	[mosaicView setFade:1.0];
	
	[self useMosaicAtIndex:0];
}


- (IBAction)setOriginalImage:(id)sender
{
	[self useMosaicAtIndex:[originalImageMatrix selectedColumn]];
	[kioskView setNeedsDisplayInRect:NSMakeRect(NSMinX([mosaicView frame]), 
														NSMaxY([mosaicView frame]), 
														NSWidth([mosaicView frame]), 
														NSMinY([originalImageMatrix frame]) - 
															NSMaxY([mosaicView frame]))];
}


- (void)setTileCount:(int)count
{
	MacOSaiXRectangularTileShapes	*tileShapes = [[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init];
	[tileShapes setTilesAcross:count];
	[tileShapes setTilesDown:count];
	
	NSEnumerator					*mosaicEnumerator = [mosaics objectEnumerator];
	MacOSaiXMosaic					*mosaic = nil;
	while (mosaic = [mosaicEnumerator nextObject])
		if ([mosaic isKindOfClass:[MacOSaiXMosaic class]])
			[mosaic setTileShapes:tileShapes creatingTiles:YES];

	[tileShapes release];
	
	[kioskView setTileCount:count];
}


#pragma mark
#pragma mark Message view

- (void)setMessage:(NSAttributedString *)message
{
	[messageView setMessage:message];
}


- (void)setMessageBackgroundColor:(NSColor *)color
{
	[messageView setBackgroundColor:color];
}


#pragma mark
#pragma mark Keywords


- (IBAction)addKeyword:(id)sender
{
	NSArray			*keywords = [[keywordTextField stringValue] componentsSeparatedByString:@";"];
	NSEnumerator	*keywordEnumerator = [keywords objectEnumerator];
	NSString		*keyword = nil;
	
	while (keyword = [keywordEnumerator nextObject])
	{
		BOOL				imageSourceExists = NO;
		NSEnumerator		*imageSourceEnumerator = [[currentMosaic imageSources] objectEnumerator];
		GoogleImageSource	*imageSource = nil;
		while (!imageSourceExists && (imageSource = [imageSourceEnumerator nextObject]))
			imageSourceExists = [[imageSource requiredTerms] isEqualToString:keyword];
		
		if (!imageSourceExists)
		{
			GoogleImageSource	*newSource = [[NSClassFromString(@"GoogleImageSource") alloc] init];
			[newSource setAdultContentFiltering:strictFiltering];
			[newSource setRequiredTerms:keyword];
			
			[currentMosaic addImageSource:newSource];
			
			[newSource release];
		}
	}
	
	[keywordTextField setStringValue:@""];
}


- (IBAction)removeKeyword:(id)sender
{
	int	selectedRow = [imageSourcesTableView selectedRow];
	
	if (selectedRow == -1)
		NSBeep();
	else
		[currentMosaic removeImageSource:[[currentMosaic imageSources] objectAtIndex:selectedRow]];
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
	
		// Position the message view in the upper right corner of the window.
	[messageView setFrame:NSMakeRect(matrixWidth + transitionWidth, mosaicHeight + transitionHeight, 
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
			NSImage	*image = [[[mosaics objectAtIndex:column] originalImage] copy];
			
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
		return [[currentMosaic imageSources] count];
	
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	id	objectValue = nil;
	
    if (tableView == imageSourcesTableView)
    {
		id<MacOSaiXImageSource>	imageSource = [[currentMosaic imageSources] objectAtIndex:rowIndex];
		
		if ([[tableColumn identifier] isEqualToString:@"Count"])
			return [NSNumber numberWithUnsignedLong:[currentMosaic countOfImagesFromSource:imageSource]];
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
			[selectedImageSources addObject:[[currentMosaic imageSources] objectAtIndex:rowIndex]];
		}
		
		[removeKeywordButton setEnabled:([selectedImageSources count] > 0)];
	}
}


#pragma mark


- (void)dealloc
{
	[mosaics release];
	[mosaicControllers release];
	
	[super dealloc];
}


@end
