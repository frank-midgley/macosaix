//
//  MacOSaiXExportController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXExportController.h"

#import "MacOSaiXImageCache.h"


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
		[unitsPopUp selectItemWithTag:[unitsTag intValue]];
	if (resolutionTag && [resolutionPopUp indexOfItemWithTag:[resolutionTag intValue]])
		[resolutionPopUp selectItemWithTag:[resolutionTag intValue]];
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
	[mosaicView setMosaicImage:[inMosaicView mosaicImage]];
	[mosaicView setNonUniqueImage:[inMosaicView nonUniqueImage]];
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
    NSSavePanel	*savePanel = [NSSavePanel savePanel];
    if ([widthField intValue] == 0)
    {
		NSSize	originalSize = [[mosaic originalImage] size];
		float	scale = 4.0;
		
		if (originalSize.width * scale > 10000.0)
			scale = 10000.0 / originalSize.width;
		if (originalSize.height * scale > 10000.0)
			scale = 10000.0 / originalSize.height;
		
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
		[unitsPopUp selectItemWithTag:1];		// pixels
		[unitsPopUp setEnabled:NO];
		[resolutionPopUp selectItemWithTag:72];	// 72 dpi
		[resolutionPopUp setEnabled:NO];
		[(NSSavePanel *)[sender window] setRequiredFileType:nil];
	}
	else
	{
		[unitsPopUp setEnabled:YES];
		[resolutionPopUp setEnabled:YES];
		[(NSSavePanel *)[sender window] setRequiredFileType:[formatExtensions objectAtIndex:imageFormat]];
	}
	
	[self setUnits:self];
}


- (NSString *)exportFormat
{
	return (createWebPage ? nil : [formatExtensions objectAtIndex:imageFormat]);
}


- (IBAction)setIncludeOriginalImage:(id)sender
{
	includeOriginalImage = ([includeOriginalButton state] == NSOnState);
}


- (IBAction)setUnits:(id)sender
{
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


- (IBAction)setResolution:(id)sender
{
}


- (IBAction)setOpenImageWhenComplete:(id)sender
{
	openWhenComplete = ([openWhenCompleteButton state] == NSOnState);
}


- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
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


- (int)exportPixelWidth
{
	return ([unitsPopUp selectedTag] == 0 ? [widthField floatValue] * [resolutionPopUp selectedTag] : 
											[widthField intValue]);
}


- (int)exportPixelHeight
{
	return ([unitsPopUp selectedTag] == 0 ? [heightField floatValue] * [resolutionPopUp selectedTag] : 
											[heightField intValue]);
}


- (void)exportMosaic:(NSString *)filename
{
    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSString				*error = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

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
	
    NSImage					*exportImage = [[NSImage alloc] initWithSize:exportRect.size];
	[exportImage setCachedSeparately:YES];
	[exportImage setCacheMode:NSImageCacheNever];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not draw images into the mosaic.  (%@)", [localException reason]];
	NS_ENDHANDLER
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	if (createWebPage)
	{
		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:filename attributes:nil];
		
		if (includeOriginalImage)
		{
			[[mosaic originalImage] drawInRect:exportRect 
									  fromRect:NSZeroRect 
									 operation:NSCompositeCopy 
									  fraction:1.0];
			
			NSBitmapImageRep	*originalRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
			NSData				*originalData = [originalRep representationUsingType:exportImageType properties:properties];
			
			[originalData writeToFile:[[filename stringByAppendingPathComponent:@"Original"] 
														stringByAppendingPathExtension:exportExtension] 
						   atomically:NO];
			[originalRep release];
		}
	}
	
	[[NSColor clearColor] set];
	NSRectFill(exportRect);
	if ([mosaicView backgroundMode] == originalMode || [mosaicView fade] < 1.0)
		[[mosaic originalImage] drawInRect:exportRect 
								  fromRect:NSZeroRect 
								 operation:NSCompositeCopy 
								  fraction:1.0];
	if ([mosaicView backgroundMode] == blackMode)
	{
		[[NSColor colorWithDeviceWhite:0.0 alpha:[mosaicView fade]] set];
		NSRectFillUsingOperation(exportRect, NSCompositeSourceOver);
	}
	// TODO: draw a user specified solid color...
	
	
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
	
	unsigned long		tileCount = [[mosaic tiles] count],
						tilesExported = 0;
	
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	
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
	while (tile = [tileEnumerator nextObject])
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
			// Get the image in use by this tile.
		MacOSaiXImageMatch	*match = [tile userChosenImageMatch];
		if (!match)
			match = [tile uniqueImageMatch];
		if (!match && [mosaicView backgroundMode] == nonUniqueMode)
			match = [tile nonUniqueImageMatch];
		
		if (match)
		{
			NS_DURING
					// Clip the tile's image to the outline of the tile.
				NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
				[NSGraphicsContext saveGraphicsState];
				[clipPath addClip];
				
					// Get the image for this tile from the cache.
				id<MacOSaiXImageSource>	imageSource = [match imageSource];
				int						imageSourceNum = [[mosaic imageSources] indexOfObjectIdenticalTo:imageSource] + 1;
				NSString				*imageIdentifier = [match imageIdentifier];
				NSImageRep				*pixletImageRep = [imageCache imageRepAtSize:[clipPath bounds].size 
																	   forIdentifier:imageIdentifier 
																		  fromSource:imageSource];
				
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
							   fraction:[mosaicView fade]];
				
					// Clean up.
				[NSGraphicsContext restoreGraphicsState];
				
				if (createWebPage)
				{
					NSValue			*sourceKey = [NSValue valueWithPointer:imageSource];
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
					
					int				thumbnailIndex = [thumbnailKeys indexOfObject:imageIdentifier];
					NSString		*thumbnailName = nil;
					
					if (thumbnailIndex == NSNotFound)
					{
						thumbnailNum = tileNum++;
						[thumbnailKeys addObject:imageIdentifier];
						[thumbnailNums addObject:[NSNumber numberWithInt:thumbnailNum]];
						if (hasMultipleSources)
							thumbnailName = [NSString stringWithFormat:@"%d-%d", imageSourceNum, [thumbnailKeys count]];
						else
							thumbnailName = [NSString stringWithFormat:@"%d", thumbnailNum + 1];
						
						NSString	*description = [imageSource descriptionForIdentifier:imageIdentifier];
						if (description)
						{
							description = [[description mutableCopy] autorelease];
							if ([description rangeOfString:@"'"].location != NSNotFound)
								NSLog(@"gotcha");
							[(NSMutableString *)description replaceOccurrencesOfString:@"'"
																			withString:@"\\'" 
																			   options:NSLiteralSearch 
																				 range:NSMakeRange(0, [description length])];
						}
						else
							description = @"";
						
							// Use the URL to the image if there is one, otherwise export a medium size thumbnail.
						NSString	*tileImageURL = [[imageSource urlForIdentifier:imageIdentifier] absoluteString];
						if (!tileImageURL)
						{
							NSImage		*thumbnailImage = [imageSource imageForIdentifier:imageIdentifier];
							NSSize		newSize = [thumbnailImage size];
							if (newSize.width > newSize.height)
								newSize = NSMakeSize(200.0, newSize.height * 200.0 / newSize.width);
							else
								newSize = NSMakeSize(newSize.width * 200.0 / newSize.height, 200.0);
							[thumbnailImage setScalesWhenResized:YES];
							[thumbnailImage setSize:newSize];
							[thumbnailImage lockFocus];
								pixletImageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, newSize.width, newSize.height)] autorelease];
							[thumbnailImage unlockFocus];
							NSData		*bitmapData = [(NSBitmapImageRep *)pixletImageRep representationUsingType:NSJPEGFileType properties:nil];
							[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%@.jpg", filename, thumbnailName] 
										 atomically:NO];
							tileImageURL = [NSString stringWithFormat:@"%@.jpg", thumbnailName];
						}
						[exportTilesHTML appendFormat:@"tiles[%d] = new tile('%@', '%@');\n", 
													  thumbnailNum, tileImageURL, description];
					}
					else
						thumbnailNum = [[thumbnailNums objectAtIndex:thumbnailIndex] intValue];
					
					NSString	*contextURL = [[imageSource contextURLForIdentifier:imageIdentifier] absoluteString];
					[exportAreasHTML appendFormat:@"\t<area shape='rect' coords='%d,%d,%d,%d' %@ " \
												  @"onmouseover='showTile(event,%d)' onmouseout='hideTile()'>\n", 
												  (int)NSMinX(drawRect), (int)([heightField intValue] - NSMaxY(drawRect)), 
												  (int)NSMaxX(drawRect), (int)([heightField intValue] - NSMinY(drawRect)), 
												  (contextURL ? [NSString stringWithFormat:@"href='%@'", contextURL] : @""),
												  thumbnailNum];
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
    NSBitmapImageRep	*exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
	NS_DURING
		[exportImage unlockFocus];
		
		if ([resolutionPopUp selectedTag] != 72)
		{
			NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
			[exportRep TIFFRepresentation];
			[pool2 release];
			
			float	scale = 72.0 / [resolutionPopUp selectedTag];
			[exportRep setSize:NSMakeSize([exportImage size].width * scale, [exportImage size].height * scale)];
		}
		
		NSData					*bitmapData = [exportRep representationUsingType:exportImageType properties:properties];
		
		if (createWebPage)
		{
			[bitmapData writeToFile:[[filename stringByAppendingPathComponent:@"Mosaic"] 
												stringByAppendingPathExtension:exportExtension] 
						 atomically:NO];
			
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
			[exportHTML writeToFile:[filename stringByAppendingPathComponent:@"index.html"] atomically:NO];
		}
		else
			[bitmapData writeToFile:filename atomically:YES];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not convert the mosaic to the requested format.  (%@)",
												 [localException reason]];
	NS_ENDHANDLER
	
	if (!error && openWhenComplete)
		[[NSWorkspace sharedWorkspace] openFile:[filename stringByAppendingPathComponent:@"index.html"]];
	
	if (didEndSelector)
		[delegate performSelector:didEndSelector withObject:error];
	
    [pool release];
    [exportRep release];
    [exportImage release];
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
	float	originalAspectRatio = originalImageSize.width / originalImageSize.height, 
			width = 0.0, 
			height = 0.0;
	
	if ([notification object] == widthField)
	{
		NSString	*widthString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
		if ([[widthField formatter] isPartialStringValid:widthString newEditingString:nil errorDescription:nil])
		{
			width = [widthString floatValue];
			[heightField setFloatValue:width / originalAspectRatio];
		}
	}
	else
		width = [widthField floatValue];
	
	if ([notification object] == heightField)
	{
		NSString	*heightString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
		if ([[heightField formatter] isPartialStringValid:heightString newEditingString:nil errorDescription:nil])
		{
			height = [heightString floatValue];
			[widthField setFloatValue:height * originalAspectRatio];
		}
	}
	else
		height = [heightField floatValue];
	
	if ([unitsPopUp selectedTag] == 0)
	{
		width *= [resolutionPopUp selectedTag];
		height *= [resolutionPopUp selectedTag];
	}
	
	NSButton	*saveButton = [self bottomRightButtonInWindow:[[notification object] window]];
	if (width <= 0.0 || width > 10000.0 || height <= 0.0 || height >= 10000.0)
		[saveButton setEnabled:NO];
	else
		[saveButton setEnabled:YES];
}


@end
