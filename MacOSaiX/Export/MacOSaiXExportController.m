//
//  MacOSaiXExportController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXExportController.h"

#import "MacOSaiXImageCache.h"


enum { jpegFormat, tiffFormat, webPageFormat };
static NSArray	*formatExtensions = nil;

@implementation MacOSaiXExportController


+ (void)initialize
{
	formatExtensions = [[NSArray arrayWithObjects:@"jpg", @"tiff", @"html", nil] retain];
}


- (id)initWithMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (self = [super initWithWindow:nil])
	{
		mosaic = inMosaic;
	}
	
	return self;
}


- (NSString *)windowNibName
{
	return @"Export";
}


- (void)exportMosaicWithName:(NSString *)name 
						fade:(float)defaultFade 
			  modalForWindow:(NSWindow *)window 
			   modalDelegate:(id)inDelegate
			progressSelector:(SEL)inProgressSelector
			  didEndSelector:(SEL)inDidEndSelector
{
	if (!accessoryView)
		[self window];
	
	[fadeSlider setFloatValue:defaultFade];
	[self setFade:self];
	
	delegate = inDelegate;
	progressSelector = ([delegate respondsToSelector:inProgressSelector] ? inProgressSelector : nil);
	didEndSelector = ([delegate respondsToSelector:inDidEndSelector] ? inDidEndSelector : nil);
	
		// Set up the save panel for exporting.
    NSSavePanel	*savePanel = [NSSavePanel savePanel];
	NSString	*extension = [formatExtensions objectAtIndex:format];
    if ([widthField intValue] == 0)
    {
		NSSize	originalSize = [[mosaic originalImage] size];
		float	scale = 4.0;
		
		if (originalSize.width * scale > 10000.0)
			scale = 10000.0 / originalSize.width;
		if (originalSize.height * scale > 10000.0)
			scale = 10000.0 / originalSize.height;
			
        [widthField setIntValue:(int)(originalSize.width * scale + 0.5)];
        [heightField setIntValue:(int)(originalSize.height * scale + 0.5)];
    }
	[savePanel setCanSelectHiddenExtension:YES];
    [savePanel setRequiredFileType:extension];
    [savePanel setAccessoryView:accessoryView];
	
		// Ask the user where to export the image.
    [savePanel beginSheetForDirectory:NSHomeDirectory()
								 file:[name stringByAppendingPathExtension:extension]
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


- (IBAction)setFade:(id)sender
{
	NSImage	*fadedImage = [[mosaic originalImage] copy];
	
// TODO:
//	[fadedImage lockFocus];
//		[[mosaicView image] drawInRect:NSMakeRect(0.0, 0.0, [fadedImage size].width, [fadedImage size].height) 
//							  fromRect:NSZeroRect 
//							 operation:NSCompositeSourceOver 
//							  fraction:[fadeSlider floatValue]];
//	[fadedImage unlockFocus];
	
	[fadedImageView setImage:fadedImage];
	[fadedImage release];
}


- (IBAction)setFormat:(id)sender
{
    format = [formatMatrix selectedRow];
	
	if (format == webPageFormat)
	{
		[unitsPopUp selectItemWithTag:1];			// pixels
		[unitsPopUp setEnabled:NO];
		[resolutionPopUp selectItemWithTag:72];	// 72 dpi
		[resolutionPopUp setEnabled:NO];
	}
	else
	{
		[unitsPopUp setEnabled:YES];
		[resolutionPopUp setEnabled:YES];
	}
	
    [(NSSavePanel *)[sender window] setRequiredFileType:[formatExtensions objectAtIndex:format]];
}


- (IBAction)setUnits:(id)sender
{
}


- (IBAction)setResolution:(id)sender
{
}


- (IBAction)setOpenImageWhenComplete:(id)sender
{
	openImageWhenComplete = ([openWhenCompleteButton state] == NSOnState);
}


- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
		if (progressSelector)
			[delegate performSelector:progressSelector 
						   withObject:[NSNumber numberWithInt:0] 
						   withObject:@"Exporting mosaic image..."];
		
			// Spawn a thread to do the export so the GUI doesn't get tied up.
		[NSApplication detachDrawingThread:@selector(exportMosaic:)
								  toTarget:self 
								withObject:[(NSSavePanel *)sheet filename]];
	}
}


- (void)exportMosaic:(NSString *)filename
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*error = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

    NSImage		*exportImage = [[NSImage alloc] initWithSize:NSMakeSize([widthField intValue], [heightField intValue])];
	[exportImage setCachedSeparately:YES];
	[exportImage setCacheMode:NSImageCacheNever];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not draw images into the mosaic.  (%@)", [localException reason]];
	NS_ENDHANDLER
	
	NSRect		exportRect = NSMakeRect(0.0, 0.0, [widthField intValue], [heightField intValue]);
	
	[[mosaic originalImage] drawInRect:exportRect 
							  fromRect:NSZeroRect 
							 operation:NSCompositeCopy 
							  fraction:1.0];
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
	
	unsigned long		tileCount = [[mosaic tiles] count],
						tilesExported = 0;
	
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	
	NSMutableString		*exportTilesHTML = [NSMutableString string], 
						*exportAreasHTML = [NSMutableString string];
	NSMutableArray		*tileKeys = [NSMutableArray array];
	NSString			*tileImagesPath = nil;
	
	NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (tile = [tileEnumerator nextObject])
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
			// Get the image in use by this tile.
		MacOSaiXImageMatch	*match = [tile displayedImageMatch];
		
		if (match)
		{
			NS_DURING
					// Clip the tile's image to the outline of the tile.
				NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
				[NSGraphicsContext saveGraphicsState];
				[clipPath addClip];
				
					// Get the image for this tile from the cache.
				NSImageRep			*pixletImageRep = [imageCache imageRepAtSize:[clipPath bounds].size 
																   forIdentifier:[match imageIdentifier] 
																	  fromSource:[match imageSource]];
				
					// Translate the tile's outline (in unit space) to the size of the exported image.
				NSRect		drawRect;
				if ([clipPath bounds].size.width / [pixletImageRep size].width <
					[clipPath bounds].size.height / [pixletImageRep size].height)
				{
					drawRect.size = NSMakeSize([clipPath bounds].size.height * [pixletImageRep size].width /
								[pixletImageRep size].height,
								[clipPath bounds].size.height);
					drawRect.origin = NSMakePoint([clipPath bounds].origin.x - 
									(drawRect.size.width - [clipPath bounds].size.width) / 2.0,
								[clipPath bounds].origin.y);
				}
				else
				{
					drawRect.size = NSMakeSize([clipPath bounds].size.width,
								[clipPath bounds].size.width * [pixletImageRep size].height /
								[pixletImageRep size].width);
					drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
								[clipPath bounds].origin.y - 
									(drawRect.size.height - [clipPath bounds].size.height) / 2.0);
				}
				
					// Finally, draw the tile's image.
				NSImage *pixletImage = [[[NSImage alloc] initWithSize:[pixletImageRep size]] autorelease];
				[pixletImage addRepresentation:pixletImageRep];
				[pixletImage drawInRect:drawRect 
							   fromRect:NSZeroRect 
							  operation:NSCompositeSourceOver 
							   fraction:[fadeSlider floatValue]];
				
					// Clean up.
				[NSGraphicsContext restoreGraphicsState];
				
				if (format == webPageFormat)
				{
					NSArray		*key = [NSArray arrayWithObjects:[match imageSource], [match imageIdentifier], nil];
					int			tileNum = [tileKeys indexOfObject:key];
					
					if (tileNum == NSNotFound)
					{
						[tileKeys addObject:key];
						tileNum = [tileKeys count];
						
							// Use the URL to the image if there is one, otherwise export a medium size thumbnail.
						NSString	*tileImageURL = [[[match imageSource] urlForIdentifier:[match imageIdentifier]] absoluteString];
						if (tileImageURL)
							[exportTilesHTML appendFormat:@"\t\ttiles[%d] = new tile('%@', '%@');\n", 
								tileNum, tileImageURL, [match imageIdentifier]];
						else
						{
							NSString	*description = [[match imageSource] descriptionForIdentifier:[match imageIdentifier]];
							if (!description)
								description = @"No description";
							[exportTilesHTML appendFormat:@"\t\ttiles[%d] = new tile('TileImages/%d.jpg', '%@');\n", 
								tileNum, tileNum, [match imageIdentifier]];
							
							if (!tileImagesPath)
							{
								tileImagesPath = [[[filename stringByDeletingLastPathComponent] 
																stringByAppendingPathComponent:@"TileImages"] retain];
								[[NSFileManager defaultManager] createDirectoryAtPath:tileImagesPath attributes:nil];
							}
							
							NSSize	newSize = [clipPath bounds].size;
							if (newSize.width > newSize.height)
								newSize = NSMakeSize(200.0, newSize.height * 200.0 / newSize.width);
							else
								newSize = NSMakeSize(newSize.width * 200.0 / newSize.height, 200.0);
							pixletImageRep = [imageCache imageRepAtSize:newSize 
														  forIdentifier:[match imageIdentifier] 
															 fromSource:[match imageSource]];
							NSData	*bitmapData = [(NSBitmapImageRep *)pixletImageRep representationUsingType:NSJPEGFileType properties:nil];
							[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%d.jpg", tileImagesPath, tileNum] 
										 atomically:NO];
						}
					}
					
					[exportAreasHTML appendFormat:@"\t<area shape='rect' coords='%d,%d,%d,%d' nohref " \
												  @"onmouseover='showTile(%d)' onmouseout='hideTile()'>\n", 
												  (int)NSMinX(drawRect), (int)([heightField intValue] - NSMaxY(drawRect)), 
												  (int)NSMaxX(drawRect), (int)([heightField intValue] - NSMinY(drawRect)), 
												  tileNum];
				}
			NS_HANDLER
				NSLog(@"Exception during export: %@", localException);
				[NSGraphicsContext restoreGraphicsState];
			NS_ENDHANDLER
		}
			
		if (progressSelector)
			[delegate performSelector:progressSelector 
						   withObject:[NSNumber numberWithDouble:((double)tilesExported / (double)tileCount * 100.0)] 
						   withObject:[NSString stringWithFormat:@"Exporting tile %d of %d...", tilesExported, tileCount]];
		
		tilesExported++;
		
        [pool2 release];
    }
	
		// Now convert the image into the desired output format.
    NSBitmapImageRep	*exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [exportImage size].width, 
									     [exportImage size].height)];
	NS_DURING
		[exportImage unlockFocus];

		NSData		*bitmapData = (format == jpegFormat || format == webPageFormat) ? 
										[exportRep representationUsingType:NSJPEGFileType properties:nil] :
										[exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
		
		if (format == webPageFormat)
		{
			NSString		*export1HTML = [[NSBundle mainBundle] pathForResource:@"Export1" ofType:@"html"];
			NSMutableString	*exportHTML = [NSMutableString stringWithContentsOfFile:export1HTML];
			[exportHTML appendString:exportTilesHTML];
			NSString		*export2HTML = [[NSBundle mainBundle] pathForResource:@"Export2" ofType:@"html"];
			[exportHTML appendString:[NSString stringWithContentsOfFile:export2HTML]];
			[exportHTML appendString:exportAreasHTML];
			NSString		*export3HTML = [[NSBundle mainBundle] pathForResource:@"Export3" ofType:@"html"];
			[exportHTML appendString:[NSString stringWithContentsOfFile:export3HTML]];
			[exportHTML writeToFile:filename atomically:YES];
			[bitmapData writeToFile:[[filename stringByDeletingLastPathComponent] 
										stringByAppendingPathComponent:@"Mosaic.jpg"] 
						 atomically:YES];
			[tileImagesPath release];
		}
		else
			[bitmapData writeToFile:filename atomically:YES];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not convert the mosaic to the requested format.  (%@)",
												 [localException reason]];
	NS_ENDHANDLER
	
    [pool release];
    [exportRep release];
    [exportImage release];
	
	if (!error && openImageWhenComplete)
		[[NSWorkspace sharedWorkspace] openFile:filename];
	
	if (didEndSelector)
		[delegate performSelector:didEndSelector withObject:error];
}


#pragma mark -
#pragma mark Text field delegate methods


- (NSButton *)bottomRightButtonInWindow:(NSWindow *)window
{
	NSButton		*bottomRightButton = nil;
	NSMutableArray	*viewQueue = [NSMutableArray arrayWithObject:[window contentView]];
	NSPoint			maxOrigin = {0.0, 0.0};
	
	while ([viewQueue count] > 0)
	{
		NSView	*nextView = [viewQueue objectAtIndex:0];
		[viewQueue removeObjectAtIndex:0];
		if ([nextView isKindOfClass:[NSButton class]])	//&& [nextView frame].origin.y > 0.0)
		{
			//			NSLog(@"Checking \"%@\" at %f, %f", [(NSButton *)nextView title], [nextView frame].origin.x, [nextView frame].origin.y);
			if ([nextView frame].origin.x > maxOrigin.x)	//|| [nextView frame].origin.y < maxOrigin.y)
			{
				bottomRightButton = (NSButton *)nextView;
				maxOrigin = [nextView frame].origin;
			}
		}
		else
			[viewQueue addObjectsFromArray:[nextView subviews]];
	}
	
	return bottomRightButton;
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	originalImageSize = [[mosaic originalImage] size];
	
	if ([notification object] == widthField)
		[heightField setFloatValue:[widthField intValue] / originalImageSize.width * originalImageSize.height];
	else if ([notification object] == heightField)
		[widthField setFloatValue:[heightField intValue] / originalImageSize.height * originalImageSize.width];
	
	NSButton	*saveButton = [self bottomRightButtonInWindow:[[notification object] window]];
	float		maxBitmapSize = ([unitsPopUp indexOfSelectedItem] == 0) ? 10000.0 / [resolutionPopUp selectedTag] : 10000.0;
	if ([widthField floatValue] > maxBitmapSize || [heightField floatValue] > maxBitmapSize)
	{
		NSBeep();
		[saveButton setEnabled:NO];
	}
	else
		[saveButton setEnabled:YES];
}


@end
