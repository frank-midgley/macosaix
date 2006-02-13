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
	formatExtensions = [[NSArray arrayWithObjects:@"jpg", @"png", @"tiff", nil] retain];
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
    [savePanel setRequiredFileType:[formatExtensions objectAtIndex:imageFormat]];
    [savePanel setAccessoryView:accessoryView];
	
		// Ask the user where to export the image.
    [savePanel beginSheetForDirectory:nil 
								 file:[name stringByAppendingPathExtension:[formatExtensions objectAtIndex:imageFormat]]
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


- (IBAction)setFade:(id)sender
{
	NSImage	*fadedImage = [[mosaic originalImage] copy];
	
// TODO: need the image from the mosaic view...
//	[fadedImage lockFocus];
//		[[mosaicView image] drawInRect:NSMakeRect(0.0, 0.0, [fadedImage size].width, [fadedImage size].height) 
//							  fromRect:NSZeroRect 
//							 operation:NSCompositeSourceOver 
//							  fraction:[fadeSlider floatValue]];
//	[fadedImage unlockFocus];
	
	[fadedImageView setImage:fadedImage];
	[fadedImage release];
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
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*error = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

    NSImage		*exportImage = [[NSImage alloc] initWithSize:NSMakeSize([self exportPixelWidth], [self exportPixelHeight])];
	[exportImage setCachedSeparately:YES];
	[exportImage setCacheMode:NSImageCacheNever];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not draw images into the mosaic.  (%@)", [localException reason]];
	NS_ENDHANDLER
	
	NSRect		exportRect = NSMakeRect(0.0, 0.0, [exportImage size].width, [exportImage size].height);
	
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
	if (createWebPage)
	{
		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:filename attributes:nil];
	}
			
	NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (tile = [tileEnumerator nextObject])
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
			// Get the image in use by this tile.
		MacOSaiXImageMatch	*match = [tile userChosenImageMatch];
		if (!match)
			match = [tile uniqueImageMatch];
		
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
				
				if (createWebPage)
				{
					NSArray		*key = [NSArray arrayWithObjects:[match imageSource], [match imageIdentifier], nil];
					int			thumbnailNum = [tileKeys indexOfObject:key];
					
					if (thumbnailNum == NSNotFound)
					{
						[tileKeys addObject:key];
						thumbnailNum = [tileKeys count];
						
							// Use the URL to the image if there is one, otherwise export a medium size thumbnail.
						NSString	*tileImageURL = [[[match imageSource] urlForIdentifier:[match imageIdentifier]] absoluteString];
						if (tileImageURL)
							[exportTilesHTML appendFormat:@"\t\ttiles[%d] = new tile('%@', '%@');\n", 
								thumbnailNum, tileImageURL, [match imageIdentifier]];
						else
						{
							NSString	*description = [[match imageSource] descriptionForIdentifier:[match imageIdentifier]];
							if (!description)
								description = @"No description";
							[exportTilesHTML appendFormat:@"\t\ttiles[%d] = new tile('%d.jpg', '%@');\n", 
								thumbnailNum, thumbnailNum, description];
							
							NSImage	*thumbnailImage = [[match imageSource] imageForIdentifier:[match imageIdentifier]];
							NSSize	newSize = [thumbnailImage size];
							if (newSize.width > newSize.height)
								newSize = NSMakeSize(200.0, newSize.height * 200.0 / newSize.width);
							else
								newSize = NSMakeSize(newSize.width * 200.0 / newSize.height, 200.0);
							[thumbnailImage setScalesWhenResized:YES];
							[thumbnailImage setSize:newSize];
							[thumbnailImage lockFocus];
								pixletImageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, newSize.width, newSize.height)] autorelease];
							[thumbnailImage unlockFocus];
							NSData	*bitmapData = [(NSBitmapImageRep *)pixletImageRep representationUsingType:NSJPEGFileType properties:nil];
							[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%d.jpg", filename, thumbnailNum] 
										 atomically:NO];
						}
					}
					else
						thumbnailNum++;
					
					NSString	*contextURL = [[[match imageSource] contextURLForIdentifier:[match imageIdentifier]] absoluteString];
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
    NSBitmapImageRep	*exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [exportImage size].width, 
									     [exportImage size].height)];
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
		
		NSBitmapImageFileType	type;
		NSMutableDictionary		*properties = [NSMutableDictionary dictionary];
		if (imageFormat == jpegFormat)
			type = NSJPEGFileType;
		else if (imageFormat == pngFormat)
			type = NSPNGFileType;
		else if (imageFormat == tiffFormat)
		{
			type = NSTIFFFileType;	// TODO: NSTIFFCompressionLZW factor 1.0
			[properties setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:NSImageCompressionMethod];
		}
		
		NSData					*bitmapData = [exportRep representationUsingType:type properties:properties];
		
		if (createWebPage)
		{
			[bitmapData writeToFile:[[filename stringByAppendingPathComponent:@"Mosaic"] 
												stringByAppendingPathExtension:[formatExtensions objectAtIndex:imageFormat]] 
						 atomically:NO];
			
			NSString		*export1HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export1" ofType:@"html"];
			NSMutableString	*exportHTML = [NSMutableString stringWithContentsOfFile:export1HTMLPath];
			[exportHTML appendString:exportTilesHTML];
			NSString		*export2HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export2" ofType:@"html"];
			NSMutableString	*export2HTML = [NSMutableString stringWithContentsOfFile:export2HTMLPath];
			[export2HTML replaceOccurrencesOfString:@"$(FORMAT_EXTENSION)" 
										 withString:[formatExtensions objectAtIndex:imageFormat] 
											options:NSLiteralSearch 
											  range:NSMakeRange(0, [export2HTML length])];
			[exportHTML appendString:export2HTML];
			[exportHTML appendString:exportAreasHTML];
			NSString		*export3HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export3" ofType:@"html"];
			[exportHTML appendString:[NSString stringWithContentsOfFile:export3HTMLPath]];
			[exportHTML writeToFile:[filename stringByAppendingPathComponent:@"index.html"] atomically:NO];
		}
		else
			[bitmapData writeToFile:filename atomically:YES];
	NS_HANDLER
		error = [NSString stringWithFormat:@"Could not convert the mosaic to the requested format.  (%@)",
												 [localException reason]];
	NS_ENDHANDLER
	
	if (!error && openImageWhenComplete)
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
