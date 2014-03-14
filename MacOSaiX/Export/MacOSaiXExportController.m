//
//  MacOSaiXExportController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXExportController.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXExportSavePanel.h"
#import "MacOSaiXSourceImage.h"


enum { jpegFormat, pngFormat, tiffFormat };
static NSArray	*formatExtensions = nil;

@implementation MacOSaiXExportController


+ (void)initialize
{
		// This array must be in sync with the enum above.
	formatExtensions = [[NSArray arrayWithObjects:@"jpg", @"png", @"tiff", nil] retain];
}


- (NSString *)windowNibName
{
	return @"Export";
}


- (void)awakeFromNib
{
	NSDictionary	*exportDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Export Defaults"];
	NSNumber		*unitsTag = [exportDefaults objectForKey:@"Units"], 
					*resolutionTag = [exportDefaults objectForKey:@"Resolution"], 
					*createWebPageBool = [exportDefaults objectForKey:@"Wrap in Web Page"], 
					*includeOriginalBool = [exportDefaults objectForKey:@"Include Original in Web Page"], 
					*openWhenCompleteBool = [exportDefaults objectForKey:@"Open When Complete"];
	NSString		*formatExtension = [exportDefaults objectForKey:@"Image Format"];
	
	if (unitsTag && [unitsPopUp indexOfItemWithTag:[unitsTag intValue]])
	{
		[unitsPopUp selectItemAtIndex:[unitsPopUp indexOfItemWithTag:[unitsTag intValue]]];
		
		if ([unitsPopUp selectedTag] == 0)
		{
			[[widthField formatter] setFormat:@"0.0#"];
			[[heightField formatter] setFormat:@"0.0#"];
		}
		else
		{
			[[widthField formatter] setFormat:@"0"];
			[[heightField formatter] setFormat:@"0"];
		}
	}
	if (resolutionTag && [resolutionPopUp indexOfItemWithTag:[resolutionTag intValue]])
		[resolutionPopUp selectItemAtIndex:[resolutionPopUp indexOfItemWithTag:[resolutionTag intValue]]];
	if (createWebPageBool)
		[createWebPageButton setState:((createWebPage = [createWebPageBool boolValue]) ? NSOnState : NSOffState)];
	if (includeOriginalBool)
		[includeOriginalButton setState:((includeOriginalImage = [includeOriginalBool boolValue]) ? NSOnState : NSOffState)];
	if (openWhenCompleteBool)
		[openWhenCompleteButton setState:((openWhenComplete = [openWhenCompleteBool boolValue]) ? NSOnState : NSOffState)];
	if (formatExtension && [formatExtensions containsObject:formatExtension])
		[formatMatrix selectCellAtRow:(imageFormat = [formatExtensions indexOfObject:formatExtension])
							   column:0];
}


- (void)exportMosaic:(MacOSaiXMosaic *)inMosaic
			withName:(NSString *)name 
		  mosaicView:(MosaicView *)inMosaicView 
	  modalForWindow:(NSWindow *)window 
	   modalDelegate:(id)inDelegate
	progressSelector:(SEL)inProgressSelector
	  didEndSelector:(SEL)inDidEndSelector
{
	if (!accessoryView)
		[self window];
	
	mosaic = inMosaic;

	[mosaicView setMosaic:mosaic];
	[mosaicView setMainImage:[inMosaicView mainImage]];
	[mosaicView setBackgroundImage:[inMosaicView backgroundImage]];
	[mosaicView setFade:[inMosaicView fade]];
	[fadeSlider setFloatValue:[mosaicView fade]];
	
	delegate = inDelegate;
	progressSelector = ([delegate respondsToSelector:inProgressSelector] ? inProgressSelector : nil);
	didEndSelector = ([delegate respondsToSelector:inDidEndSelector] ? inDidEndSelector : nil);
	
		// Pause the mosaic so we don't have a moving target.
//	BOOL		wasPaused = [mosaic isPaused];
    [mosaic pause];
	// TODO:
	//     Restore pause state:		if (wasPaused) [mosaic resume];
	
		// Set up the save panel for exporting.
    NSSavePanel	*savePanel = [MacOSaiXExportSavePanel savePanel];
	[savePanel setDelegate:self];
    if ([widthField floatValue] == 0.0)
    {
		NSSize	originalSize = [[mosaic originalImage] size];
		float	originalArea = originalSize.width * originalSize.height, 
				maxArea = 10000.0 * 10000.0, 
				scale = 4.0;
		
		if (originalArea * scale * scale > maxArea)
			scale = sqrt(maxArea / originalArea);
		
		if ([unitsPopUp selectedTag] == 0)
		{
			[widthField setFloatValue:originalSize.width * scale / [resolutionPopUp selectedTag]];
			[heightField setFloatValue:originalSize.height * scale / [resolutionPopUp selectedTag]];
		}
		else
		{
			[widthField setIntValue:(int)(originalSize.width * scale + 0.5)];
			[heightField setIntValue:(int)(originalSize.height * scale + 0.5)];
		}
    }
	[savePanel setCanSelectHiddenExtension:YES];
    [savePanel setAccessoryView:accessoryView];
	
	NSString	*exportFormat = [self exportFormat];
    [savePanel setRequiredFileType:exportFormat];
	
		// Ask the user where to export the image.
    [savePanel beginSheetForDirectory:nil 
								 file:(exportFormat ? [name stringByAppendingPathExtension:exportFormat] : name)
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


- (IBAction)setBackground:(id)sender
{
	[mosaicView setBackgroundMode:[sender selectedTag]];
}


- (IBAction)setFade:(id)sender
{
	[mosaicView setFade:[fadeSlider floatValue]];
}


- (IBAction)setImageFormat:(id)sender
{
    imageFormat = [formatMatrix selectedRow];
	
	if (!createWebPage)
		[(NSSavePanel *)[sender window] setRequiredFileType:[formatExtensions objectAtIndex:imageFormat]];
}


- (IBAction)setCreateWebPage:(id)sender
{
	createWebPage = ([createWebPageButton state] == NSOnState);
	
	if (createWebPage)
	{
		if ([unitsPopUp selectedTag] == 0)
		{
			[unitsPopUp selectItemAtIndex:[unitsPopUp indexOfItemWithTag:1]];		// pixels
			[self setUnits:self];
		}
		[unitsPopUp setEnabled:NO];
		[resolutionPopUp selectItemAtIndex:[resolutionPopUp indexOfItemWithTag:72]];	// 72 dpi
		[resolutionPopUp setEnabled:NO];
		[(NSSavePanel *)[sender window] setRequiredFileType:nil];
	}
	else
	{
		[unitsPopUp setEnabled:YES];
		[resolutionPopUp setEnabled:YES];
		[(NSSavePanel *)[sender window] setRequiredFileType:[formatExtensions objectAtIndex:imageFormat]];
	}
}


- (NSString *)exportFormat
{
	return (createWebPage ? nil : [formatExtensions objectAtIndex:imageFormat]);
}


- (IBAction)setIncludeOriginalImage:(id)sender
{
	includeOriginalImage = ([includeOriginalButton state] == NSOnState);
}


- (int)exportPixelWidth
{
	NSString	*widthString = nil;
	
	if ([widthField currentEditor])
	{
		widthString = [[widthField currentEditor] string];
		
		if (![[widthField formatter] isPartialStringValid:widthString newEditingString:nil errorDescription:nil])
			widthString = nil;
	}
	else
		widthString = [widthField stringValue];
	
	return ([unitsPopUp selectedTag] == 0 ? [widthString floatValue] * [resolutionPopUp selectedTag] : [widthString intValue]);
}


- (int)exportPixelHeight
{
	NSString	*heightString = nil;
	
	if ([heightField currentEditor])
	{
		heightString = [[heightField currentEditor] string];
		
		if (![[heightField formatter] isPartialStringValid:heightString newEditingString:nil errorDescription:nil])
			heightString = nil;
	}
	else
		heightString = [heightField stringValue];
	
	return ([unitsPopUp selectedTag] == 0 ? [heightString floatValue] * [resolutionPopUp selectedTag] : [heightString intValue]);
}


- (BOOL)exportCouldCrash
{
	int			width = [self exportPixelWidth], 
				height = [self exportPixelHeight];
	
	return (width <= 0 || height <= 0 || (float)width * (float)height >= 10000.0 * 10000.0);
}


- (void)checkExportSize
{
	if ([self exportCouldCrash])
		[warningImageView setImage:[NSImage imageNamed:@"Warning"]];
	else
		[warningImageView setImage:nil];
}


- (IBAction)setUnits:(id)sender
{
	if ([unitsPopUp selectedTag] == 0)
	{
		float	dpi = [resolutionPopUp selectedTag],
				width = [widthField intValue] / dpi, 
				height = [heightField intValue] / dpi;
		
		[[widthField formatter] setFormat:@"0.0#"];
		[widthField setFloatValue:width];
		
		[[heightField formatter] setFormat:@"0.0#"];
		[heightField setFloatValue:height];
	}
	else
	{
		float	dpi = [resolutionPopUp selectedTag],
				width = [widthField intValue] * dpi, 
				height = [heightField intValue] * dpi;
		
		[[widthField formatter] setFormat:@"0"];
		[widthField setFloatValue:width];
		
		[[heightField formatter] setFormat:@"0"];
		[heightField setFloatValue:height];
	}
	
	[self checkExportSize];
}


- (IBAction)setResolution:(id)sender
{
	[self checkExportSize];
}


- (IBAction)setOpenImageWhenComplete:(id)sender
{
	openWhenComplete = ([openWhenCompleteButton state] == NSOnState);
}


- (IBAction)cancelExport:(id)sender
{
	exportCancelled = YES;
}


- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet makeFirstResponder:nil];
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
			// Save the current settings as the defaults for future exports.
		NSDictionary	*exportDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
												[NSNumber numberWithInt:[unitsPopUp selectedTag]], @"Units", 
												[NSNumber numberWithInt:[resolutionPopUp selectedTag]], @"Resolution", 
												[formatExtensions objectAtIndex:imageFormat], @"Image Format", 
												[NSNumber numberWithBool:createWebPage], @"Wrap in Web Page", 
												[NSNumber numberWithBool:includeOriginalImage], @"Include Original in Web Page", 
												[NSNumber numberWithBool:openWhenComplete], @"Open When Complete", 
												nil];
		[[NSUserDefaults standardUserDefaults] setObject:exportDefaults forKey:@"Export Defaults"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
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
    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSString				*error = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Don't allow non-thread safe QuickTime component access on this thread.
	CSSetComponentsThreadMode(kCSAcceptThreadSafeComponentsOnlyMode);
	
	exportCancelled = NO;
	
	NSString				*exportExtension = [formatExtensions objectAtIndex:imageFormat];
	NSBitmapImageFileType	exportImageType = jpegFormat;
	NSMutableDictionary		*properties = [NSMutableDictionary dictionary];
	if (imageFormat == jpegFormat)
		exportImageType = NSJPEGFileType;
	else if (imageFormat == pngFormat)
		exportImageType = NSPNGFileType;
	else if (imageFormat == tiffFormat)
	{
		exportImageType = NSTIFFFileType;	// TODO: NSTIFFCompressionLZW factor 1.0
		[properties setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:NSImageCompressionMethod];
	}
	
	NSRect					exportRect = NSMakeRect(0.0, 0.0, [self exportPixelWidth], [self exportPixelHeight]);
	NSBitmapImageRep		*exportRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
																				 pixelsWide:NSWidth(exportRect) 
																				 pixelsHigh:NSHeight(exportRect) 
																			  bitsPerSample:8 
																			samplesPerPixel:4 
																				   hasAlpha:YES 
																				   isPlanar:NO 
																			 colorSpaceName:NSDeviceRGBColorSpace 
																				bytesPerRow:0 
																			   bitsPerPixel:0];
	if (!exportRep)
		error = @"Could not get enough memory to create the image.";
	
	NSGraphicsContext		*exportContext = [NSGraphicsContext graphicsContextWithAttributes:[NSDictionary dictionaryWithObject:exportRep 
																														  forKey:NSGraphicsContextDestinationAttributeName]];
	NSImage					*exportImage = nil;
	
//	if (exportRep && !exportContext)
//		error = @"Could not set up to draw the image.";
	
	if (exportContext)
	{
		[exportContext setImageInterpolation:NSImageInterpolationHigh];
		[NSGraphicsContext setCurrentContext:exportContext];
	}
	else
	{
		exportImage = [[NSImage alloc] initWithSize:exportRect.size];
		[exportImage setCachedSeparately:YES];
		[exportImage setCacheMode:NSImageCacheNever];
		NS_DURING
			[exportImage lockFocus];
		NS_HANDLER
			error = [NSString stringWithFormat:@"Could not draw images into the mosaic.  (%@)", [localException reason]];
		NS_ENDHANDLER
	}
	
	if (!error && createWebPage)
	{
		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:filename attributes:nil];
		
		if (includeOriginalImage)
		{
			[[mosaic originalImage] drawInRect:exportRect 
									  fromRect:NSZeroRect 
									 operation:NSCompositeSourceOver 
									  fraction:1.0];
			
			NSBitmapImageRep	*originalRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
			NSData				*originalData = [originalRep representationUsingType:exportImageType properties:properties];
			
			[originalData writeToFile:[[filename stringByAppendingPathComponent:@"Original"] 
														stringByAppendingPathExtension:exportExtension] 
						   atomically:NO];
			[originalRep release];
		}
	}
	
	if (!error)
	{
		// Draw the appropriate background.
		
		[[NSColor clearColor] set];
		NSRectFill(exportRect);
		if ([mosaicView backgroundMode] == originalMode || [mosaicView fade] < 1.0)
			[[mosaic originalImage] drawInRect:exportRect 
									  fromRect:NSZeroRect 
									 operation:NSCompositeSourceOver 
									  fraction:1.0];
		if ([mosaicView backgroundMode] == blackMode)
		{
			[[NSColor colorWithDeviceWhite:0.0 alpha:[mosaicView fade]] set];
			NSRectFillUsingOperation(exportRect, NSCompositeSourceOver);
		}
	}
	
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform scaleXBy:NSWidth(exportRect) yBy:NSHeight(exportRect)];
	
	unsigned long		tileCount = [[mosaic tiles] count],
						tilesExported = 0;
	
		// Set up data for web exporting
	NSMutableString		*exportTilesHTML = [NSMutableString string], 
						*exportAreasHTML = [NSMutableString string];
	NSMutableDictionary	*thumbnailKeyArrays = [NSMutableDictionary dictionary],
						*thumbnailNumArrays = [NSMutableDictionary dictionary];
	int					tileNum = 0;
	BOOL				hasMultipleSources = ([[mosaic imageSources] count] > 1);
	
		// Add each tile to the image and optionally to the web page.
	NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (!error && !exportCancelled && (tile = [tileEnumerator nextObject]))
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
			// Get the image to show in this tile.
		MacOSaiXImageMatch	*match = [tile userChosenImageMatch];
		if (!match)
			match = [tile uniqueImageMatch];
		if (!match && [mosaicView backgroundMode] == bestMatchMode)
			match = [tile bestImageMatch];
		
		if (match)
		{
			MacOSaiXSourceImage	*pixletSourceImage = [match sourceImage];
			NSRect				drawRect = NSZeroRect;
			
			NS_DURING
				[NSGraphicsContext saveGraphicsState];
				
					// Clip the tile's image to the outline of the tile.
				NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
				[clipPath addClip];
				
					// Get the image for this tile from the cache.
				NSBitmapImageRep		*pixletImageRep = [pixletSourceImage imageRepAtSize:[clipPath bounds].size];
				
					// Translate the tile's outline (in unit space) to the size of the exported image.
				NSSize		clipSize = [clipPath bounds].size,
							pixletSize = [pixletImageRep size];
				if (clipSize.width / pixletSize.width < clipSize.height / pixletSize.height)
				{
					drawRect.size = NSMakeSize(clipSize.height * pixletSize.width / pixletSize.height,
											   clipSize.height);
					drawRect.origin = NSMakePoint(NSMinX([clipPath bounds]) - 
												  (NSWidth(drawRect) - clipSize.width) / 2.0,
												  NSMinY([clipPath bounds]));
				}
				else
				{
					drawRect.size = NSMakeSize(clipSize.width,
											   clipSize.width * pixletSize.height / pixletSize.width);
					drawRect.origin = NSMakePoint(NSMinX([clipPath bounds]),
												  NSMinY([clipPath bounds]) - 
												  (NSHeight(drawRect) - clipSize.height) / 2.0);
				}
				
//				drawRect = NSMakeRect(floor(NSMinX(drawRect)), 
//									  floor(NSMinY(drawRect)), 
//									  ceil(NSMaxX(drawRect)) - floorf(NSMinX(drawRect)), 
//									  ceil(NSMaxY(drawRect)) - floorf(NSMinY(drawRect)));
//				NSLog(@"x:%g-%g y:%g-%g", NSMinX(drawRect), NSMaxX(drawRect), NSMinY(drawRect), NSMaxY(drawRect));
				
					// Finally, draw the tile's image.
				NSImage		*pixletImage = [[[NSImage alloc] initWithSize:pixletSize] autorelease];
				[pixletImage addRepresentation:pixletImageRep];
				[pixletImage drawInRect:drawRect 
							   fromRect:NSZeroRect 
							  operation:NSCompositeSourceOver 
							   fraction:[mosaicView fade]];
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Exception exporting tile %d: %@", tileNum, localException);
				#endif
			NS_ENDHANDLER
			
				// Clean up.
			[NSGraphicsContext restoreGraphicsState];
			
			if (createWebPage)
			{
				NS_DURING
					NSValue			*sourceKey = [NSValue valueWithPointer:[pixletSourceImage source]];
					NSMutableArray	*thumbnailKeys = [thumbnailKeyArrays objectForKey:sourceKey], 
									*thumbnailNums = [thumbnailNumArrays objectForKey:sourceKey];
					int				thumbnailNum = 0;
					
					if (!thumbnailKeys)
					{
						thumbnailKeys = [NSMutableArray array];
						[thumbnailKeyArrays setObject:thumbnailKeys forKey:sourceKey];
						thumbnailNums = [NSMutableArray array];
						[thumbnailNumArrays setObject:thumbnailNums forKey:sourceKey];
					}
					
					unsigned long	thumbnailIndex = [thumbnailKeys indexOfObject:[pixletSourceImage identifier]];
					NSString		*thumbnailName = nil;
					
					if (thumbnailIndex == NSNotFound)
					{
						thumbnailNum = tileNum++;
						[thumbnailKeys addObject:[pixletSourceImage identifier]];
						[thumbnailNums addObject:[NSNumber numberWithInt:thumbnailNum]];
						if (hasMultipleSources)
						{
							int		imageSourceNum = [[mosaic imageSources] indexOfObjectIdenticalTo:[pixletSourceImage source]] + 1;
							thumbnailName = [NSString stringWithFormat:@"%d-%d", imageSourceNum, [thumbnailKeys count]];
						}
						else
							thumbnailName = [NSString stringWithFormat:@"%d", thumbnailNum + 1];
						
						NSString	*description = [pixletSourceImage description];
						if (description)
						{
							description = [[description mutableCopy] autorelease];
							[(NSMutableString *)description replaceOccurrencesOfString:@"'"
																			withString:@"\\'" 
																			   options:NSLiteralSearch 
																				 range:NSMakeRange(0, [description length])];
						}
						else
							description = @"";
						
							// Use the URL to the image if there is one, otherwise export a medium size thumbnail.
						NSString	*tileImageURL = [[pixletSourceImage URL] absoluteString];
						if (!tileImageURL)
						{
							// TBD: why isn't this using the cache?
							NSImage		*thumbnailImage = [[pixletSourceImage source] imageForIdentifier:[pixletSourceImage identifier]];
							NSSize		newSize = [thumbnailImage size];
							if (newSize.width > newSize.height)
								newSize = NSMakeSize(200.0, newSize.height * 200.0 / newSize.width);
							else
								newSize = NSMakeSize(newSize.width * 200.0 / newSize.height, 200.0);
							[thumbnailImage setScalesWhenResized:YES];
							[thumbnailImage setSize:newSize];
							NSBitmapImageRep	*thumbnailRep = nil;	// TBD: go via TIFF to preserve alpha?
							[thumbnailImage lockFocus];
								thumbnailRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, newSize.width, newSize.height)] autorelease];
							[thumbnailImage unlockFocus];
							NSData		*bitmapData = [thumbnailRep representationUsingType:NSJPEGFileType properties:nil];
							[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%@.jpg", filename, thumbnailName] 
										 atomically:NO];
							tileImageURL = [NSString stringWithFormat:@"%@.jpg", thumbnailName];
						}
						[exportTilesHTML appendFormat:@"tiles[%d] = new tile('%@', '%s');\n", 
													  thumbnailNum, tileImageURL, [description UTF8String]];
					}
					else
						thumbnailNum = [[thumbnailNums objectAtIndex:thumbnailIndex] intValue];
					
					NSURL			*contextURL = [pixletSourceImage contextURL];
					NSMutableString	*contextURLString = (contextURL ? [NSMutableString stringWithString:[[pixletSourceImage contextURL] absoluteString]] : nil);
					[contextURLString replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [contextURLString length])];
					
					[exportAreasHTML appendFormat:@"\t<area shape='rect' coords='%d,%d,%d,%d' %@ " \
												  @"onmouseover='showTile(event,%d)' onmouseout='hideTile()' alt='Tile'>\n", 
												  (int)NSMinX(drawRect), (int)(NSHeight(exportRect) - NSMaxY(drawRect)), 
												  (int)NSMaxX(drawRect), (int)(NSHeight(exportRect) - NSMinY(drawRect)), 
												  (contextURLString ? [NSString stringWithFormat:@"href=\"%@\"", contextURLString] : @""),
												  thumbnailNum];
				NS_HANDLER
					#ifdef DEBUG
						NSLog(@"Exception exporting web details for tile %d: %@", tileNum, localException);
					#endif
				NS_ENDHANDLER
			}
		}
			
		if (progressSelector)
			[delegate performSelector:progressSelector 
						   withObject:[NSNumber numberWithDouble:((double)tilesExported / (double)tileCount * 100.0)] 
						   withObject:@"Drawing tile images..."];
		
		tilesExported++;
		
        [pool2 release];
    }	
    
// Draw the original inset into the mosaic. (Hard coded to Dad's 70th mosaic.
//    NSRect originalRect = NSMakeRect(125.0, 55.0, 400.0, 490.0);
//    NSFrameRectWithWidth(NSInsetRect(originalRect, -2.0, -2.0), 2.0);
//    [[mosaic originalImage] drawInRect:originalRect 
//                              fromRect:NSZeroRect 
//                             operation:NSCompositeSourceOver 
//                              fraction:1.0];
	
	if (exportImage)
	{
		if (!error && !exportCancelled)
			exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
		
		[exportImage unlockFocus];
		[exportImage release];
		exportImage = nil;
	}
	
	if (!error && !exportCancelled)
	{
		// Now convert the image into the desired output format.
		
		if (progressSelector)
			[delegate performSelector:progressSelector 
						   withObject:[NSNumber numberWithDouble:0.0] 
						   withObject:[NSString stringWithFormat:@"Converting to %@ format...", [exportExtension uppercaseString]]];
		
		NS_DURING
				// Set the resolution.
			float				scale = 72.0 / [resolutionPopUp selectedTag];
			NSSize				scaledExportSize = NSMakeSize(NSWidth(exportRect) * scale, NSHeight(exportRect) * scale);
			[exportRep setSize:scaledExportSize];
			
				// Convert the bitmap rep into the desired format and deallocate the rep.
			NSData				*bitmapData = [exportRep representationUsingType:exportImageType properties:properties];
			[exportRep release];
			exportRep = nil;
			
			if (!bitmapData || [bitmapData length] == 0)
				[NSException raise:@"" format:@"The mosaic could not be converted to %@ format", [exportExtension uppercaseString]];
			
			if (progressSelector)
				[delegate performSelector:progressSelector 
							   withObject:[NSNumber numberWithDouble:0.0] 
							   withObject:[NSString stringWithFormat:@"Saving %@ image...", [exportExtension uppercaseString]]];
			
			if (createWebPage)
			{
				[bitmapData writeToFile:[[filename stringByAppendingPathComponent:@"Mosaic"] 
													stringByAppendingPathExtension:exportExtension] 
							 atomically:NO];
				
				if (progressSelector)
					[delegate performSelector:progressSelector 
								   withObject:[NSNumber numberWithDouble:0.0] 
								   withObject:@"Saving web page..."];
				
				NSString		*export1HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export1" ofType:@"html"];
				NSMutableString	*exportHTML = [NSMutableString stringWithContentsOfFile:export1HTMLPath];
				[exportHTML appendString:exportTilesHTML];
				NSString		*export2HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export2" ofType:@"html"];
				[exportHTML appendString:[NSString stringWithContentsOfFile:export2HTMLPath]];
				NSString		*export3HTMLPath = nil;
				if (includeOriginalImage)
					export3HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export3+Original" ofType:@"html"];
				else
					export3HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export3" ofType:@"html"];
				NSMutableString	*export3HTML = [NSMutableString stringWithContentsOfFile:export3HTMLPath];
				[export3HTML replaceOccurrencesOfString:@"$(FORMAT_EXTENSION)" 
											 withString:exportExtension 
												options:NSLiteralSearch 
												  range:NSMakeRange(0, [export3HTML length])];
				[exportHTML appendString:export3HTML];
				NSString		*export4HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export4" ofType:@"html"];
				[exportHTML appendString:[NSString stringWithContentsOfFile:export4HTMLPath]];
				[exportHTML appendString:exportAreasHTML];
				NSString		*export5HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export5" ofType:@"html"];
				[exportHTML appendString:[NSString stringWithContentsOfFile:export5HTMLPath]];
				filename = [filename stringByAppendingPathComponent:@"index.html"];
				[exportHTML writeToFile:filename atomically:NO];
			}
			else
				[bitmapData writeToFile:filename atomically:YES];
		NS_HANDLER
			error = [NSString stringWithFormat:@"Could not convert the mosaic to the requested format.  (%@)",
													 [localException reason]];
		NS_ENDHANDLER
	}
	
	if (exportRep)
		[exportRep release];
		
	if (error || exportCancelled)
		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
	else if (openWhenComplete)
		[[NSWorkspace sharedWorkspace] openFile:filename];
	
	if (didEndSelector)
		[delegate performSelector:didEndSelector withObject:error];
	
    [pool release];
}


#pragma mark -
#pragma mark Text field delegate methods


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	originalImageSize = [[mosaic originalImage] size];
	float	originalAspectRatio = originalImageSize.width / originalImageSize.height;
	
	if ([notification object] == widthField)
	{
		NSString	*widthString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
		
		if ([[widthField formatter] isPartialStringValid:widthString newEditingString:nil errorDescription:nil])
			[heightField setFloatValue:[widthString floatValue] / originalAspectRatio];
	}
	else if ([notification object] == heightField)
	{
		NSString	*heightString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
		
		if ([[heightField formatter] isPartialStringValid:heightString newEditingString:nil errorDescription:nil])
			[widthField setFloatValue:[heightString floatValue] * originalAspectRatio];
	}
	
	[self checkExportSize];
}


@end
