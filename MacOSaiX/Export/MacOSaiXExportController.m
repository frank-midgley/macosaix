//
//  MacOSaiXExportController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXExportController.h"

//#import <ApplicationServices/ApplicationServices.h>

#import "MacOSaiX.h"
#import "MacOSaiXExporter.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatch.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXProgressController.h"
#import "MacOSaiXSourceImage.h"
#import "NSImage+MacOSaiX.h"
//#import "NSBezierPath+MacOSaiX.h"
#import "Tiles.h"


//enum { jpegFormat, pngFormat, tiffFormat };
//static NSArray	*formatExtensions = nil;

@implementation MacOSaiXExportController


//+ (void)initialize
//{
//		// This array must be in sync with the enum above.
//	formatExtensions = [[NSArray arrayWithObjects:@"jpg", @"png", @"tiff", nil] retain];
//}


//- (void)awakeFromNib
//{
//	NSDictionary	*exportDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Export Defaults"];
//	NSNumber		*unitsTag = [exportDefaults objectForKey:@"Units"], 
//					*resolutionTag = [exportDefaults objectForKey:@"Resolution"], 
//					*createWebPageBool = [exportDefaults objectForKey:@"Wrap in Web Page"], 
//					*includeTargetBool = [exportDefaults objectForKey:@"Include Target in Web Page"], 
//					*openWhenCompleteBool = [exportDefaults objectForKey:@"Open When Complete"];
//	NSString		*formatExtension = [exportDefaults objectForKey:@"Image Format"];
//	
//	if (unitsTag && [unitsPopUp indexOfItemWithTag:[unitsTag intValue]])
//		[unitsPopUp selectItemAtIndex:[unitsPopUp indexOfItemWithTag:[unitsTag intValue]]];
//	if (resolutionTag && [resolutionPopUp indexOfItemWithTag:[resolutionTag intValue]])
//		[resolutionPopUp selectItemAtIndex:[resolutionPopUp indexOfItemWithTag:[resolutionTag intValue]]];
//	if (createWebPageBool)
//		[createWebPageButton setState:((createWebPage = [createWebPageBool boolValue]) ? NSOnState : NSOffState)];
//	if (includeTargetBool)
//		[includeTargetButton setState:((includeTargetImage = [includeTargetBool boolValue]) ? NSOnState : NSOffState)];
//	if (openWhenCompleteBool)
//		[openWhenCompleteButton setState:((openWhenComplete = [openWhenCompleteBool boolValue]) ? NSOnState : NSOffState)];
//	if (formatExtension && [formatExtensions containsObject:formatExtension])
//		[formatMatrix selectCellAtRow:(imageFormat = [formatExtensions indexOfObject:formatExtension])
//							   column:0];
//}


- (void)exportMosaic:(MacOSaiXMosaic *)inMosaic
			withName:(NSString *)name 
	  modalForWindow:(NSWindow *)window 
	   modalDelegate:(id)inDelegate
	  didEndSelector:(SEL)inDidEndSelector
{
	mosaic = inMosaic;
	delegate = inDelegate;
	didEndSelector = ([delegate respondsToSelector:inDidEndSelector] ? inDidEndSelector : nil);
	
		// Pause the mosaic so we don't have a moving target.
//	BOOL		wasPaused = [mosaic isPaused];
    [mosaic pause];
	// TODO:
	//     Restore pause state:		if (wasPaused) [mosaic resume];
	
		// Work with a copy of the export settings in case the user cancels.
	exportSettings = [[mosaic exportSettings] copyWithZone:[self zone]];
	[exportSettings setTargetImage:[mosaic targetImage]];
	
		// Set up the save panel for exporting.
    savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setDelegate:self];
	
	[NSBundle loadNibNamed:@"Export" owner:self];
	
		// Populate the format pop-up with the list of the current exporter plug-ins.
	[formatPopUp removeAllItems];
	NSMenu			*formatMenu = [formatPopUp menu];
	NSEnumerator	*plugInEnumerator = [[[NSApp delegate] exporterPlugIns] objectEnumerator];
	Class			exporterPlugIn = nil, 
					currentClass = [exportSettings class];
	NSMenuItem		*currentItem = nil;
	while (exporterPlugIn = [plugInEnumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:exporterPlugIn];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSMenuItem		*menuItem = [[[NSMenuItem alloc] initWithTitle:plugInName action:@selector(addImageSource:) keyEquivalent:@""] autorelease];
		
		[menuItem setImage:[[[exporterPlugIn image] copyWithLargestDimension:32] autorelease]];
		[menuItem setRepresentedObject:exporterPlugIn];
		[menuItem setTarget:self];
		[menuItem setAction:@selector(setFormat:)];
		
		[formatMenu addItem:menuItem];
		
		if ((!currentClass && !currentItem) || [exporterPlugIn dataSourceClass] == currentClass)
			currentItem = menuItem;
	}
	
	[formatPopUp selectItem:currentItem];
	[self setFormat:currentItem];
	
	NSString	*exportExtension = [exportSettings exportExtension];
    [savePanel setRequiredFileType:exportExtension];
	
		// Ask the user where to export.
    [savePanel beginSheetForDirectory:nil 
								 file:(exportExtension ? [name stringByAppendingPathExtension:exportExtension] : name)
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:window];
}


- (IBAction)setFormat:(id)sender
{
	Class			plugInClass = [sender representedObject];
	
	if (exporterEditor)
	{
		[exporterEditor editingDidComplete];
		[exporterEditor release];
	}
	
		// Create new settings for this format if necessary.
	if (![exportSettings isKindOfClass:[plugInClass dataSourceClass]])
	{
		[exportSettings release];
		exportSettings = [[[plugInClass dataSourceClass] alloc] init];
	}
	[exportSettings setTargetImage:[mosaic targetImage]];
	
		// Create an editor for this format's settings.
	exporterEditor = [[[plugInClass editorClass] alloc] initWithDelegate:self];
	
		// Add the editor's custom view to the save panel.
	NSView			*editorView = [exporterEditor editorView];
	NSRect			editorFrame = [editorView frame], 
					accessoryFrame = NSMakeRect(0.0, 0.0, NSWidth(editorFrame), NSHeight(editorFrame) + NSHeight([sharedView frame]) + 10.0);
	NSView			*accessoryView = [[[NSView alloc] initWithFrame:accessoryFrame] autorelease];
	[sharedView setFrame:NSMakeRect(0.0, NSHeight(editorFrame) + 10.0, NSWidth(accessoryFrame), NSHeight([sharedView frame]))];
	[accessoryView addSubview:sharedView];
	[accessoryView addSubview:editorView];
	[savePanel setAccessoryView:accessoryView];
	
		// Set the correct file extension.
    [savePanel setRequiredFileType:[exportSettings exportExtension]];
	
		// Tell the editor which settings to edit.
	[exporterEditor editDataSource:exportSettings];
}


//- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag
//{
//	if (okFlag)
//	{
//		bitmapBuffer = malloc([self exportPixelWidth] * [self exportPixelHeight] * 4);
//		
//		if (!bitmapBuffer)
//		{
//			NSRunAlertPanel(NSLocalizedString(@"There is not enough memory available to save the mosaic at that size.", @""), 
//							NSLocalizedString(@"Please choose a smaller width, height or resolution.", @""), 
//							NSLocalizedString(@"OK", @""), nil, nil);
//			filename = nil;
//		}
//	}
//	
//	return filename;
//}


- (NSImage *)targetImage
{
	return [mosaic targetImage];
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource 
	  didChangeKey:(NSString *)key
		 fromValue:(id)previousValue 
		actionName:(NSString *)actionName;
{
    [savePanel setRequiredFileType:[exportSettings exportExtension]];
}


- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSWindow					*window = (NSWindow *)contextInfo;
	
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
		[mosaic setExportSettings:exportSettings];
		
		progressController = [[MacOSaiXProgressController alloc] initWithWindow:nil];
		[progressController setCancelTarget:self action:@selector(cancelExport:)];
		[progressController displayPanelWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Saving the mosaic in %@ format...", @""), 
																			   [exportSettings exportFormat]]
									 modalForWindow:window];
		
			// Spawn a thread to do the export so the GUI doesn't get tied up.
		NSDictionary	*threadParameters = [NSDictionary dictionaryWithObjectsAndKeys:
												[savePanel URL], @"Export URL", 
												nil];
		[NSApplication detachDrawingThread:@selector(exportMosaic:)
								  toTarget:self 
								withObject:threadParameters];
	}
	
	savePanel = nil;
}


- (void)exportMosaic:(NSDictionary *)threadParameters
{
    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	unsigned long			tileCount = [[mosaic tiles] count],
							tilesExported = 0;
	NSURL					*exportURL = [threadParameters objectForKey:@"Export URL"];
	Class					exporterPlugInClass = [[NSApp delegate] plugInForDataSourceClass:[exportSettings class]];
	id<MacOSaiXExporter>	exporter = [[[exporterPlugInClass exporterClass] alloc] init];
	id						exportError = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
	exportWasCancelled = NO;
	
	NS_DURING
		exportError = [exporter openFileAtURL:exportURL withSettings:exportSettings];
	NS_HANDLER
		exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not open the save file.  (%@)", @""), 
												 [localException reason]];
	NS_ENDHANDLER
	
	if (exportError)
	{
		// TODO: check the error
	}
	else
	{
			// Export the contents of each tile.
		NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
		MacOSaiXTile		*tile = nil;
		while (!exportWasCancelled && !exportError && (tile = [tileEnumerator nextObject]))
		{
			NSAutoreleasePool		*tilePool = [[NSAutoreleasePool alloc] init];
			MacOSaiXTileFillStyle	fillStyle = [tile fillStyle];
			
//			[progressController setMessage:NSLocalizedString(@"Saving tile %d of %d...", @""), tilesExported + 1, tileCount];
			[progressController setPercentComplete:[NSNumber numberWithDouble:(100.0 * tilesExported / tileCount)]];
			
			if (fillStyle == fillWithColor || fillStyle == fillWithAverageTargetColor)
			{
				NS_DURING
					exportError = [exporter fillTileWithColor:[tile fillColor] clippedToPath:[tile outline]];
				NS_HANDLER
					exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
															 [localException reason]];
				NS_ENDHANDLER
			}
			else if (fillStyle == fillWithTargetImage)
			{
				NSImage	*targetImage = [mosaic targetImage];
				
				NS_DURING
					exportError = [exporter fillTileWithImage:targetImage 
											   withIdentifier:[mosaic targetImageIdentifier] 
												   fromSource:[mosaic targetImageSource] 
											  centeredAtPoint:NSMakePoint([targetImage size].width / 2.0, 
																		  [targetImage size].height / 2.0) 
													 rotation:0.0 
												clippedToPath:[tile outline]];
				NS_HANDLER
					exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
						[localException reason]];
				NS_ENDHANDLER
			}
			else
			{
				MacOSaiXSourceImage	*tileSourceImage = nil;
				
					// Get the identifier and source of the image with which to fill the tile.
				if (fillStyle == fillWithUniqueMatch)
					tileSourceImage = [[tile uniqueImageMatch] sourceImage];
				else if (fillStyle == fillWithHandPicked)
					tileSourceImage = [[tile userChosenImageMatch] sourceImage];
				
				if (tileSourceImage)
				{
						// Fetch the appropriate image from the cache.
						// TBD: Is there some way to avoid having to pull the full sized image when it's not needed?  
						//      Additional exporter API that lets us know the rendered size of the tile?
					NSSize				nativeSize = [tileSourceImage nativeSize];
					NSImageRep			*tileImageRep = [tileSourceImage imageRepAtSize:nativeSize];
					NSImage				*tileImage = [[NSImage alloc] initWithSize:[tileImageRep size]];
					[tileImage addRepresentation:tileImageRep];
					[tileImage setScalesWhenResized:NO];
					
						// Size the image to fit this tile, accounting for the orientation.  The bitmap rep will not be resized.  The image's size tells the exporter how big the bitmap should be rendered (in the target image's space).
					NSBezierPath		*targetOutline = [tile outline];
					NSRect				targetBounds = [targetOutline bounds];
					NSAffineTransform	*transform = [NSAffineTransform transform];
					[transform translateXBy:NSMidX(targetBounds) yBy:NSMidY(targetBounds)];
					[transform rotateByDegrees:-[tile imageOrientation]];
					[transform translateXBy:-NSMidX(targetBounds) yBy:-NSMidY(targetBounds)];
					NSBezierPath		*rotatedOutline = [transform transformBezierPath:targetOutline];
					NSRect				rotatedBounds = [rotatedOutline bounds];
					BOOL				widthLimited = ((nativeSize.width / NSWidth(rotatedBounds)) < 
														(nativeSize.height / NSHeight(rotatedBounds)));
					float				scale = (widthLimited ? NSWidth(rotatedBounds) / nativeSize.width : NSHeight(rotatedBounds) / nativeSize.height);
					[tileImage setSize:NSMakeSize(nativeSize.width * scale, nativeSize.height * scale)];
					
						// Tell the exporter where and how to draw the image.
					NS_DURING
						exportError = [exporter fillTileWithImage:tileImage 
												   withIdentifier:[tileSourceImage imageIdentifier] 
													   fromSource:[[tileSourceImage enumerator] imageSource] 
												  centeredAtPoint:NSMakePoint(NSMidX(targetBounds), NSMidY(targetBounds)) 
														 rotation:[tile imageOrientation] 
													clippedToPath:[tile outline]];
					NS_HANDLER
						exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
																 [localException reason]];
					NS_ENDHANDLER
					
					[tileImage release];
				}
			}
			
			tilesExported++;
			
			[tilePool release];
		}
		
		[progressController setMessage:NSLocalizedString(@"Finishing the save...", @"")];
		[progressController setPercentComplete:[NSNumber numberWithInt:-1]];
		NS_DURING
			exportError = [exporter closeFile];
		NS_HANDLER
			exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not finish saving the mosaic.  (%@)", @""), 
													 [localException reason]];
		NS_ENDHANDLER
	}
	
	[progressController closePanel];
	
	if (didEndSelector)
		[delegate performSelector:didEndSelector withObject:exportError];

    [pool release];
}


- (IBAction)cancelExport:(id)sender
{
	exportWasCancelled = YES;
}


//- (void)exportMosaic:(NSString *)filename
//{
//    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
//	NSString				*error = nil;
//	
//		// Don't usurp the main thread.
//	[NSThread setThreadPriority:0.1];
//	
//	exportWasCancelled = NO;
//	
//	NSString				*exportExtension = [formatExtensions objectAtIndex:imageFormat];
//	NSBitmapImageFileType	exportImageType = jpegFormat;
//	NSMutableDictionary		*properties = [NSMutableDictionary dictionary];
//	if (imageFormat == jpegFormat)
//		exportImageType = NSJPEGFileType;
//	else if (imageFormat == pngFormat)
//		exportImageType = NSPNGFileType;
//	else if (imageFormat == tiffFormat)
//	{
//		exportImageType = NSTIFFFileType;	// TODO: NSTIFFCompressionLZW factor 1.0
//		[properties setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:NSImageCompressionMethod];
//	}
//	
//	int						exportWidth = [self exportPixelWidth], 
//							exportHeight = [self exportPixelHeight];
//#define USE_CG 1
//	
//#if USE_CG
//	CGRect				cgExportRect = CGRectMake(0.0, 0.0, exportWidth, exportHeight);
//	CGColorSpaceRef		cgColorSpace = CGColorSpaceCreateDeviceRGB();
//	CGContextRef		cgContext = CGBitmapContextCreate(bitmapBuffer, 
//														  exportWidth, 
//														  exportHeight, 
//														  8, 
//														  exportWidth * 4, 
//														  cgColorSpace, 
//														  kCGImageAlphaPremultipliedLast);
//	CGContextSetInterpolationQuality(cgContext, kCGInterpolationHigh);
//	NSBitmapImageRep	*targetImageRep = nil;
//	CGDataProviderRef	cgDataProvider = NULL;
//	CGImageRef			cgTargetImage	= NULL;
//	
//	if (createWebPage)
//	{
//			// Create a CG version of the target image.
//		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
//		NSData				*tiffData = [[mosaic targetImage] TIFFRepresentation];
//		
//		targetImageRep = [[NSBitmapImageRep alloc] initWithData:tiffData];
//		cgDataProvider = CGDataProviderCreateWithData(NULL, 
//													  [targetImageRep bitmapData], 
//													  [targetImageRep bytesPerRow] * 
//													  [targetImageRep pixelsHigh], 
//													  NULL);
//		cgTargetImage = CGImageCreate([targetImageRep pixelsWide], 
//										[targetImageRep pixelsHigh], 
//										[targetImageRep bitsPerSample], 
//										[targetImageRep bitsPerPixel], 
//										[targetImageRep bytesPerRow], 
//										cgColorSpace, 
//										([targetImageRep hasAlpha] ? kCGImageAlphaPremultipliedLast : 
//											kCGImageAlphaNone), 
//										cgDataProvider, 
//										NULL, 
//										FALSE,
//										kCGRenderingIntentDefault);
//		
//		[pool2 release];
//	}
//#else
//	NSRect					exportRect = NSMakeRect(0.0, 0.0, exportWidth, exportHeight);
//	NSBitmapImageRep		*exportRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bitmapBuffer 
//																				 pixelsWide:exportWidth 
//																				 pixelsHigh:exportHeight 
//																			  bitsPerSample:8 
//																			samplesPerPixel:4 
//																				   hasAlpha:YES 
//																				   isPlanar:NO 
//																			 colorSpaceName:NSDeviceRGBColorSpace 
//																				bytesPerRow:0 
//																			   bitsPerPixel:0];
//    NSImage					*exportImage = [[NSImage alloc] initWithSize:exportRect.size];
//	[exportImage addRepresentation:exportRep];
//	[exportImage setCachedSeparately:YES];
//	[exportImage setCacheMode:NSImageCacheNever];
//	NS_DURING
//		[exportImage lockFocusOnRepresentation:exportRep];
//	NS_HANDLER
//		error = [NSString stringWithFormat:NSLocalizedString(@"Could not draw images into the mosaic.  (%@)", @""), 
//										   [localException reason]];
//	NS_ENDHANDLER
//	
//	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
//#endif
//	
//	if (createWebPage)
//	{
//		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
//		[[NSFileManager defaultManager] createDirectoryAtPath:filename attributes:nil];
//		[[NSFileManager defaultManager] copyPath:[[NSBundle mainBundle] pathForImageResource:@"Loading"] 
//										  toPath:[filename stringByAppendingPathComponent:@"Loading.png"] 
//										 handler:nil];
//		
//		if (includeTargetImage)
//		{
//			#if USE_CG
//				CGContextDrawImage(cgContext, cgExportRect, cgTargetImage);
//				NSBitmapImageRep	*targetRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bitmapBuffer 
//																						 pixelsWide:exportWidth 
//																						 pixelsHigh:exportHeight 
//																					  bitsPerSample:8 
//																					samplesPerPixel:4 
//																						   hasAlpha:YES 
//																						   isPlanar:NO 
//																					 colorSpaceName:NSDeviceRGBColorSpace 
//																						bytesPerRow:0 
//																					   bitsPerPixel:0];
//			#else
//				[[mosaic targetImage] drawInRect:exportRect 
//										  fromRect:NSZeroRect 
//										 operation:NSCompositeCopy 
//										  fraction:1.0];
//				NSBitmapImageRep	*targetRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
//			#endif
//			
//			NSData				*targetData = [targetRep representationUsingType:exportImageType properties:properties];
//			
//			[targetData writeToFile:[[filename stringByAppendingPathComponent:@"Target"] 
//													stringByAppendingPathExtension:exportExtension] 
//						 atomically:NO];
//			[targetRep release];
//		}
//	}
//	
//	#if USE_CG
//		float	clearColorComponents[2] = {0.0, 0.0};
//		CGContextSetFillColor(cgContext, clearColorComponents);
//		CGContextFillRect(cgContext, cgExportRect);
//	#else
//		[[NSColor clearColor] set];
//		NSRectFill(exportRect);
//	#endif
//
//	NSAffineTransform	*transform = [NSAffineTransform transform];
//	NSSize				targetImageSize = [[mosaic targetImage] size];
//	[transform scaleXBy:exportWidth / targetImageSize.width 
//					yBy:exportHeight / targetImageSize.height];
//	
//	#if USE_CG
//		;	// TBD: set up CG transform?
//	#endif
//	
//	unsigned long		tileCount = [[mosaic tiles] count],
//						tilesExported = 0;
//	
//	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
//	
//		// Set up data for web exporting
//	NSMutableString		*exportTilesHTML = [NSMutableString string], 
//						*exportAreasHTML = [NSMutableString string];
//	NSMutableDictionary	*thumbnailKeyArrays = [NSMutableDictionary dictionary],
//						*thumbnailNumArrays = [NSMutableDictionary dictionary];
//	int					tileNum = 0;
//	BOOL				hasMultipleSources = ([[mosaic imageSources] count] > 1);
//	
//		// Add each tile to the image and optionally to the web page.
//	NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
//	MacOSaiXTile		*tile = nil;
//	while (!exportWasCancelled && (tile = [tileEnumerator nextObject]))
//    {
//        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
//		
//			// Get the image to show in this tile.
//			// TODO: handle new fill styles
//		MacOSaiXImageMatch	*match = [tile userChosenImageMatch];
//		if (!match)
//			match = [tile uniqueImageMatch];
//		
//		if (match)
//		{
//			NS_DURING
//					// Clip the tile's image to the outline of the tile.
//				NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
//				
//				#if USE_CG
//					CGContextSaveGState(cgContext);
//					CGPathRef		cgOutline = [clipPath quartzPath];
//					CGContextAddPath(cgContext, cgOutline);
//					CGContextClip(cgContext);
//					CGPathRelease(cgOutline);
//				#else
//					[NSGraphicsContext saveGraphicsState];
//					[clipPath addClip];
//				#endif
//				
//					// Get the image for this tile from the cache.
//				id<MacOSaiXImageSource>	imageSource = [match imageSource];
//				int						imageSourceNum = [[mosaic imageSources] indexOfObjectIdenticalTo:imageSource] + 1;
//				NSString				*imageIdentifier = [match imageIdentifier];
//				NSBitmapImageRep		*pixletImageRep = (NSBitmapImageRep *)[imageCache imageRepAtSize:[clipPath bounds].size 
//																	   forIdentifier:imageIdentifier 
//																		  fromSource:imageSource];
//				
//					// Translate the tile's outline (in the target image space) to the size of the exported image.
//				NSRect		drawRect;
//				NSSize		clipSize = [clipPath bounds].size,
//							pixletSize = [pixletImageRep size];
//				if (clipSize.width / pixletSize.width < clipSize.height / pixletSize.height)
//				{
//					drawRect.size = NSMakeSize(clipSize.height * pixletSize.width / pixletSize.height,
//											   clipSize.height);
//					drawRect.origin = NSMakePoint(NSMinX([clipPath bounds]) - 
//												  (NSWidth(drawRect) - clipSize.width) / 2.0,
//												  NSMinY([clipPath bounds]));
//				}
//				else
//				{
//					drawRect.size = NSMakeSize(clipSize.width,
//											   clipSize.width * pixletSize.height / pixletSize.width);
//					drawRect.origin = NSMakePoint(NSMinX([clipPath bounds]),
//												  NSMinY([clipPath bounds]) - 
//												  (NSHeight(drawRect) - clipSize.height) / 2.0);
//				}
//				
////				drawRect = NSMakeRect(floorf(NSMinX(drawRect)), 
////									  floorf(NSMinY(drawRect)), 
////									  ceilf(NSMaxX(drawRect)) - floorf(NSMinX(drawRect)), 
////									  ceilf(NSMaxY(drawRect)) - floorf(NSMinY(drawRect)));
////				NSLog(@"x:%g-%g y:%g-%g", NSMinX(drawRect), NSMaxX(drawRect), NSMinY(drawRect), NSMaxY(drawRect));
//				
//					// Finally, draw the tile's image.
//				#if USE_CG
//					CGRect				cgTileRect = CGRectMake(drawRect.origin.x, drawRect.origin.y, 
//													drawRect.size.width, drawRect.size.height);
//					CGDataProviderRef	cgDataProvider = CGDataProviderCreateWithData(NULL, 
//																					  [pixletImageRep bitmapData], 
//																					  [pixletImageRep bytesPerRow] * 
//																						[pixletImageRep pixelsHigh], 
//																					  NULL);
//					CGBitmapInfo		cgBitmapInfo = ([pixletImageRep hasAlpha] ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone);
//					CGImageRef			cgTileImage = CGImageCreate([pixletImageRep pixelsWide], 
//																	[pixletImageRep pixelsHigh], 
//																	[pixletImageRep bitsPerSample], 
//																	[pixletImageRep bitsPerPixel], 
//																	[pixletImageRep bytesPerRow], 
//																	cgColorSpace, 
//																	cgBitmapInfo, 
//																	cgDataProvider, 
//																	NULL, 
//																	FALSE,
//																	kCGRenderingIntentDefault);
////					CGImageDestinationRef	cgImageDest = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:@"/Users/frank/Desktop/Mosaics/Pixlet.png"], 
////																						  kUTTypePNG, 
////																						  1, 
////																						  NULL);
////					CGImageDestinationAddImage(cgImageDest, cgTileImage, NULL);
////					CGImageDestinationFinalize(cgImageDest);
////					CFRelease(cgImageDest);
//					CGContextSetAlpha(cgContext, 1.0 - [mosaicView targetImageFraction]);
//					CGContextDrawImage(cgContext, cgTileRect, cgTileImage);
//					CGDataProviderRelease(cgDataProvider);
//				#else
//					NSImage *pixletImage = [[[NSImage alloc] initWithSize:pixletSize] autorelease];
//					[pixletImage addRepresentation:pixletImageRep];
//					[pixletImage drawInRect:drawRect 
//								   fromRect:NSZeroRect 
//								  operation:NSCompositeSourceOver 
//								   fraction:[mosaicView fade]];
//				#endif
//				
//					// Clean up.
//				#if USE_CG
//					CGContextRestoreGState(cgContext);
//				#else
//					[NSGraphicsContext restoreGraphicsState];
//				#endif
//				
//				if (createWebPage)
//				{
//					NSValue			*sourceKey = [NSValue valueWithPointer:imageSource];
//					NSMutableArray	*thumbnailKeys = [thumbnailKeyArrays objectForKey:sourceKey], 
//									*thumbnailNums = [thumbnailNumArrays objectForKey:sourceKey];
//					int				thumbnailNum = 0;
//					
//					if (!thumbnailKeys)
//					{
//						thumbnailKeys = [NSMutableArray array];
//						[thumbnailKeyArrays setObject:thumbnailKeys forKey:sourceKey];
//						thumbnailNums = [NSMutableArray array];
//						[thumbnailNumArrays setObject:thumbnailNums forKey:sourceKey];
//					}
//					
//					int				thumbnailIndex = [thumbnailKeys indexOfObject:imageIdentifier];
//					NSString		*thumbnailName = nil;
//					
//					if (thumbnailIndex == NSNotFound)
//					{
//						thumbnailNum = tileNum++;
//						[thumbnailKeys addObject:imageIdentifier];
//						[thumbnailNums addObject:[NSNumber numberWithInt:thumbnailNum]];
//						if (hasMultipleSources)
//							thumbnailName = [NSString stringWithFormat:@"%d-%d", imageSourceNum, [thumbnailKeys count]];
//						else
//							thumbnailName = [NSString stringWithFormat:@"%d", thumbnailNum + 1];
//						
//						NSString	*description = [imageSource descriptionForIdentifier:imageIdentifier];
//						if (description)
//						{
//							description = [[description mutableCopy] autorelease];
//							[(NSMutableString *)description replaceOccurrencesOfString:@"'"
//																			withString:@"\\'" 
//																			   options:NSLiteralSearch 
//																				 range:NSMakeRange(0, [description length])];
//						}
//						else
//							description = @"";
//						
//							// Use the URL to the image if there is one, otherwise export a medium size thumbnail.
//						NSString	*tileImageURL = [[imageSource urlForIdentifier:imageIdentifier] absoluteString];
//						if (!tileImageURL)
//						{
//							NSImage		*thumbnailImage = [imageSource imageForIdentifier:imageIdentifier];
//							NSSize		newSize = [thumbnailImage size];
//							if (newSize.width > newSize.height)
//								newSize = NSMakeSize(200.0, newSize.height * 200.0 / newSize.width);
//							else
//								newSize = NSMakeSize(newSize.width * 200.0 / newSize.height, 200.0);
//							[thumbnailImage setScalesWhenResized:YES];
//							[thumbnailImage setSize:newSize];
//							[thumbnailImage lockFocus];
//								pixletImageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, newSize.width, newSize.height)] autorelease];
//							[thumbnailImage unlockFocus];
//							NSData		*bitmapData = [(NSBitmapImageRep *)pixletImageRep representationUsingType:NSJPEGFileType properties:nil];
//							[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%@.jpg", filename, thumbnailName] 
//										 atomically:NO];
//							tileImageURL = [NSString stringWithFormat:@"%@.jpg", thumbnailName];
//						}
//						[exportTilesHTML appendFormat:@"tiles[%d] = new tile('%@', '%@');\n", 
//													  thumbnailNum, tileImageURL, description];
//					}
//					else
//						thumbnailNum = [[thumbnailNums objectAtIndex:thumbnailIndex] intValue];
//					
//					NSString	*contextURL = [[imageSource contextURLForIdentifier:imageIdentifier] absoluteString];
//					[exportAreasHTML appendFormat:@"\t<area shape='rect' coords='%d,%d,%d,%d' %@ " 
//												  @"onmouseover='showTile(event,%d)' onmouseout='hideTile()'>\n", 
//												  (int)NSMinX(drawRect), (int)([heightField intValue] - NSMaxY(drawRect)), 
//												  (int)NSMaxX(drawRect), (int)([heightField intValue] - NSMinY(drawRect)), 
//												  (contextURL ? [NSString stringWithFormat:@"href='%@'", contextURL] : @""),
//												  thumbnailNum];
//				}
//			NS_HANDLER
//				NSLog(@"Exception during export: %@", localException);
//				#if USE_CG
//					CGContextRestoreGState(cgContext);
//				#else
//					[NSGraphicsContext restoreGraphicsState];
//				#endif
//				NS_ENDHANDLER
//		}
//			
//		[progressController setMessage:NSLocalizedString(@"Saving tile %d of %d...", @""), tilesExported, tileCount];
//		[progressController setPercentComplete:[NSNumber numberWithDouble:(100.0 * tilesExported / tileCount)]];
//		
//		tilesExported++;
//		
//        [pool2 release];
//    }
//	
//	if (targetImageRep)
//	{
//		[targetImageRep release];
//		targetImageRep = nil;
//	}
//	if (cgTargetImage)
//	{
//		CGImageRelease(cgTargetImage);
//		cgTargetImage = nil;
//	}
//	if (cgDataProvider)
//	{
//		CGDataProviderRelease(cgDataProvider);
//		cgDataProvider = nil;
//	}
//		
//	if (exportWasCancelled)
//		#if !USE_CG
//			[exportImage unlockFocus];
//		#endif
//	else
//	{
//			// Now convert the image into the desired output format.
//		#if USE_CG
//			NSBitmapImageRep		*exportRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bitmapBuffer 
//																						 pixelsWide:exportWidth 
//																						 pixelsHigh:exportHeight 
//																					  bitsPerSample:8 
//																					samplesPerPixel:4 
//																						   hasAlpha:YES 
//																						   isPlanar:NO 
//																					 colorSpaceName:NSDeviceRGBColorSpace 
//																						bytesPerRow:0 
//																					   bitsPerPixel:0];
//		#else
//			exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:exportRect];
//		#endif
//		
//		NS_DURING
//			#if !USE_CG
//				[exportImage unlockFocus];
//			#endif
//			
//			if ([resolutionPopUp selectedTag] != 72)
//			{
//				#if !USE_CG
//						// Why is this being done?  It requires a ton of memory.
//					NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
//					[exportRep TIFFRepresentation];
//					[pool2 release];
//				#endif
//				
//				float	scale = 72.0 / [resolutionPopUp selectedTag];
//				[exportRep setSize:NSMakeSize(exportWidth * scale, exportHeight * scale)];
//			}
//			
//			if (imageFormat == jpegFormat)
//				[progressController setMessage:NSLocalizedString(@"Converting mosaic image to JPEG format...", @"")];
//			else if (imageFormat == pngFormat)
//				[progressController setMessage:NSLocalizedString(@"Converting mosaic image to PNG format...", @"")];
//			else if (imageFormat == tiffFormat)
//				[progressController setMessage:NSLocalizedString(@"Converting mosaic image to TIFF format...", @"")];
//			
//			NSData	*bitmapData = [exportRep representationUsingType:exportImageType properties:properties];
//			
//			[progressController setMessage:NSLocalizedString(@"Saving mosaic image...", @"")];
//			if (createWebPage)
//			{
//				[bitmapData writeToFile:[[filename stringByAppendingPathComponent:@"Mosaic"] 
//													stringByAppendingPathExtension:exportExtension] 
//							 atomically:NO];
//				
//				NSString		*export1HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export1" ofType:@"html"];
//				NSMutableString	*exportHTML = [NSMutableString stringWithContentsOfFile:export1HTMLPath];
//				[exportHTML appendString:exportTilesHTML];
//				NSString		*export2HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export2" ofType:@"html"];
//				[exportHTML appendString:[NSString stringWithContentsOfFile:export2HTMLPath]];
//				NSString		*export3HTMLPath = nil;
//				if (includeTargetImage)
//					export3HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export3+Target" ofType:@"html"];
//				else
//					export3HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export3" ofType:@"html"];
//				NSMutableString	*export3HTML = [NSMutableString stringWithContentsOfFile:export3HTMLPath];
//				[export3HTML replaceOccurrencesOfString:@"$(FORMAT_EXTENSION)" 
//											 withString:exportExtension 
//												options:NSLiteralSearch 
//												  range:NSMakeRange(0, [export3HTML length])];
//				[exportHTML appendString:export3HTML];
//				NSString		*export4HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export4" ofType:@"html"];
//				[exportHTML appendString:[NSString stringWithContentsOfFile:export4HTMLPath]];
//				[exportHTML appendString:exportAreasHTML];
//				NSString		*export5HTMLPath = [[NSBundle mainBundle] pathForResource:@"Export5" ofType:@"html"];
//				[exportHTML appendString:[NSString stringWithContentsOfFile:export5HTMLPath]];
//				filename = [filename stringByAppendingPathComponent:@"index.html"];
//				[exportHTML writeToFile:filename atomically:NO];
//			}
//			else
//				[bitmapData writeToFile:filename atomically:YES];
//		NS_HANDLER
//			error = [NSString stringWithFormat:NSLocalizedString(@"Could not convert the mosaic to the requested format.  (%@)", @""), 
//											   [localException reason]];
//		NS_ENDHANDLER
//	}
//	
//	if (error || exportWasCancelled)
//		[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
//	else if (openWhenComplete)
//		[[NSWorkspace sharedWorkspace] openFile:filename];
//	
//	[progressController closePanel];
//	
//	if (didEndSelector)
//		[delegate performSelector:didEndSelector withObject:error];
//	
//	#if USE_CG
//		CGContextRelease(cgContext);
//		CGColorSpaceRelease(cgColorSpace);
//	#else
//		[exportImage release];
//		[exportRep release];
//	#endif
//	free(bitmapBuffer);
//	bitmapBuffer = nil;
//    [pool release];
//}


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


//- (void)controlTextDidChange:(NSNotification *)notification
//{
//	NSSize	targetImageSize = [[mosaic targetImage] size];
//	float	targetAspectRatio = targetImageSize.width / targetImageSize.height, 
//			width = 0.0, 
//			height = 0.0;
//	
//	if ([notification object] == widthField)
//	{
//		NSString	*widthString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
//		if ([[widthField formatter] isPartialStringValid:widthString newEditingString:nil errorDescription:nil])
//		{
//			width = [widthString floatValue];
//			[heightField setFloatValue:width / targetAspectRatio];
//		}
//	}
//	else
//		width = [widthField floatValue];
//	
//	if ([notification object] == heightField)
//	{
//		NSString	*heightString = [[[notification userInfo] objectForKey:@"NSFieldEditor"] string];
//		if ([[heightField formatter] isPartialStringValid:heightString newEditingString:nil errorDescription:nil])
//		{
//			height = [heightString floatValue];
//			[widthField setFloatValue:height * targetAspectRatio];
//		}
//	}
//	else
//		height = [heightField floatValue];
//}


- (void)dealloc
{
	[sharedView release];
	
	[super dealloc];
}


@end
