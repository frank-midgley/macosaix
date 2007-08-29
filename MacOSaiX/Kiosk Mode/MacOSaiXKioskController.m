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
#import "MacOSaiXImageMatch.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXKioskMessageView.h"
#import "MacOSaiXKioskView.h"
#import "MacOSaiXMosaic.h"
#import "MosaicView.h"
#import "RectangularTileShapes.h"
#import "Tiles.h"

#import <pthread.h>


#define MAX_REFRESH_THREAD_COUNT 1


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
		
		if ([[currentMosaic imageSourceEnumerators] count] > 0)
		{
			int					currentIndex = [mosaics indexOfObjectIdenticalTo:currentMosaic];
			[currentMosaic setTargetImagePath:[[targetImageMatrix cellAtRow:0 column:currentIndex] title]];
			
				// Save the current mosaic for posterity.
			NSString			*saveFilePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]
																	stringByAppendingPathComponent:@"Kiosk Mosaics"];
			if (![[NSFileManager defaultManager] fileExistsAtPath:saveFilePath])
				[[NSFileManager defaultManager] createDirectoryAtPath:saveFilePath attributes:nil];
			saveFilePath = [[saveFilePath stringByAppendingPathComponent:[[NSDate date] description]]
											stringByAppendingPathExtension:@"mosaic"];
			MacOSaiXDocument	*tempDocument = [[MacOSaiXDocument alloc] init];
			[tempDocument setMosaic:currentMosaic];
			[tempDocument threadedSaveWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
														saveFilePath, @"Save Path", 
														[NSNumber numberWithBool:YES], @"Was Paused", 
														nil]];
			[tempDocument release];
		}
		
			// Remove all of the image sources.
		NSEnumerator					*imageSourceEnumeratorEnumerator = [[currentMosaic imageSourceEnumerators] objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
		while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
			[currentMosaic removeImageSource:[imageSourceEnumerator imageSource]];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:currentMosaic];
	}
	
	{
			// Switch to the new mosaic
		currentMosaic = [mosaics objectAtIndex:index];
		
		[mosaicView setMosaic:currentMosaic];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeBusyStateNotification 
												   object:currentMosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeImageSourcesNotification 
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


- (void)tile
{
	// Resize all of the views so that the target images and the mosaic maintain a 4x3 aspect ratio.
	float		windowHeight = NSHeight([[self window] frame]), 
				windowWidth = NSWidth([[self window] frame]), 
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
	
	// Position the target image matrix in the upper left corner of the window.
	[targetImageMatrix setCellSize:NSMakeSize(matrixWidth / 6.0, matrixHeight)];
	[targetImageMatrix setFrame:NSMakeRect(0.0, mosaicHeight + transitionHeight, matrixWidth, matrixHeight)];
	
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
	
	// Populate the target image buttons now that we know what size they are.
	int		column = 0;
	for (column = 0; column < [targetImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [targetImageMatrix cellAtRow:0 column:column];
		MacOSaiXMosaic	*mosaic = [mosaics objectAtIndex:column];
		
		if ([buttonCell imagePosition] == NSImageOnly && [mosaic isKindOfClass:[MacOSaiXMosaic class]])
		{
			NSImage	*image = [[mosaic targetImage] copy];
			
			[image setScalesWhenResized:YES];
			[image setSize:[targetImageMatrix cellSize]];
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


- (void)awakeFromNib
{
	[self tile];
	
		// Populate the target image buttons
	NSArray			*targetImagePaths = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Kiosk Settings"]
																				  objectForKey:@"Target Image Paths"];
	int				column = 0;
	for (column = 0; column < [targetImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [targetImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [targetImagePaths count] ? [targetImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			MacOSaiXMosaic	*mosaic = [[MacOSaiXMosaic alloc] init];
			[mosaic setTargetImagePath:imagePath];
			[mosaic setTargetImage:image];
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
	
	[mosaicView setTargetImageOpacity:0.0 animationTime:0.0];
	[mosaicView setBackgroundColor:[NSColor blackColor]];
	
	[messageView setEditable:NO];
	
	[self useMosaicAtIndex:0];
}


- (IBAction)setTargetImage:(id)sender
{
	if ([[targetImageMatrix selectedCell] imagePosition] == NSImageOnly)
	{
		[self useMosaicAtIndex:[targetImageMatrix selectedColumn]];
		[kioskView setNeedsDisplayInRect:NSMakeRect(NSMinX([mosaicView frame]), 
															NSMaxY([mosaicView frame]), 
															NSWidth([mosaicView frame]), 
															NSMinY([targetImageMatrix frame]) - 
																NSMaxY([mosaicView frame]))];
	}
	else
		[targetImageMatrix selectCellAtRow:0 column:[mosaics indexOfObjectIdenticalTo:[mosaicView mosaic]]];
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
			[mosaic setTileShapes:tileShapes];

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
		BOOL							imageSourceExists = NO;
		NSEnumerator					*imageSourceEnumeratorEnumerator = [[currentMosaic imageSourceEnumerators] objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
		while (!imageSourceExists && (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject]))
			imageSourceExists = [[(MacOSaiXGoogleImageSource *)[imageSourceEnumerator imageSource] requiredTerms] isEqualToString:keyword];
		
		if (!imageSourceExists)
		{
			MacOSaiXGoogleImageSource	*newSource = [[NSClassFromString(@"MacOSaiXGoogleImageSource") alloc] init];
			[newSource setAdultContentFiltering:strictFiltering];
			[newSource setRequiredTerms:keyword];
			
			[currentMosaic addImageSource:newSource];
			
			[newSource release];
			
			[currentMosaic resume];
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
		[currentMosaic removeImageSource:[[[currentMosaic imageSourceEnumerators] objectAtIndex:selectedRow] imageSource]];
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
	if ([notification object] == [self window])
		[self tile];
}


#pragma mark -
#pragma mark Table delegate methods


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == imageSourcesTableView)
		return [[currentMosaic imageSourceEnumerators] count];
	
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	id	objectValue = nil;
	
    if (tableView == imageSourcesTableView)
    {
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [[currentMosaic imageSourceEnumerators] objectAtIndex:rowIndex];
		
		if ([[tableColumn identifier] isEqualToString:@"Count"])
			return [NSNumber numberWithUnsignedLong:[imageSourceEnumerator numberOfImagesFound]];
		else
			objectValue = [[imageSourceEnumerator imageSource] briefDescription];
    }

	return objectValue;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == imageSourcesTableView)
		[removeKeywordButton setEnabled:([imageSourcesTableView numberOfSelectedRows] > 0)];
}


#pragma mark


- (void)dealloc
{
	[mosaics release];
	[mosaicControllers release];
	
	[super dealloc];
}


@end
