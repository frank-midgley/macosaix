//
//  MacOSaiXWebPageExporter.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWebPageExporter.h"

#import "MacOSaiXWebPageExportSettings.h"
#import "NSBezierPath+MacOSaiX.h"
#include <stdlib.h>


@implementation MacOSaiXWebPageExporter
	

- (id)createFileAtURL:(NSURL *)url 
		 withSettings:(id<MacOSaiXExportSettings>)settings
{
	exportURL = [url retain];
	exportSettings = (MacOSaiXWebPageExportSettings *)settings;
	
	[[NSFileManager defaultManager] removeFileAtPath:[exportURL path] handler:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[exportURL path] attributes:nil];
	
	int						exportWidth = [exportSettings width], 
							exportHeight = [exportSettings height];
	
	bitmapBuffer = malloc(exportWidth * exportHeight * 4);
	cgColorSpace = CGColorSpaceCreateDeviceRGB();
	cgContext = CGBitmapContextCreate(bitmapBuffer, 
									  exportWidth, 
									  exportHeight, 
									  8, 
									  exportWidth * 4, 
									  cgColorSpace, 
									  kCGImageAlphaPremultipliedLast);
	CGContextSetInterpolationQuality(cgContext, kCGInterpolationHigh);
	
	CGColorSpaceRef			rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextSetFillColorSpace(cgContext, rgbColorSpace);
	CGColorSpaceRelease(rgbColorSpace);
	
		// Start with an entirely clear bitmap.
	float					clearColorComponents[4] = {0.0, 0.0, 0.0, 0.0};
	CGContextSetFillColor(cgContext, clearColorComponents);
	CGContextFillRect(cgContext, CGRectMake(0.0, 0.0, exportWidth, exportHeight));
	
		// Create a transform to scale from the target image size to the export size.
	NSSize					targetImageSize = [[exportSettings targetImage] size];
	CGContextConcatCTM(cgContext, CGAffineTransformMakeScale(exportWidth / targetImageSize.width, 
															 exportHeight / targetImageSize.height));
	
	// TODO: #ifdef out for i386 build
	if (CGImageDestinationCreateWithURL)
	{
		CFURLRef	mosaicImageRef = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, (CFURLRef)exportURL, CFSTR("Mosaic.png"), NO);
		cgImageDest = CGImageDestinationCreateWithURL(mosaicImageRef, kUTTypePNG, 1, NULL);
		CFRelease(mosaicImageRef);
	}
	
	if ([exportSettings includeTargetImage])
	{
		NSAutoreleasePool	*targetImagePool = [[NSAutoreleasePool alloc] init];
		
			// Make a copy of the target image scaled to the same size as the mosaic image.
		NSImage				*targetImageCopy = [[[settings targetImage] copy] autorelease];
		[targetImageCopy setScalesWhenResized:YES];
		[targetImageCopy setSize:NSMakeSize(exportWidth, exportHeight)];
		
			// Create a PNG representation of the copy.
		NSBitmapImageRep	*targetRep = nil;
		[targetImageCopy lockFocus];
			targetRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, exportWidth, exportHeight)] autorelease];
		[targetImageCopy unlockFocus];
		NSData				*pngData = [targetRep representationUsingType:NSPNGFileType properties:nil];
		
			// Save the PNG data to the folder.
		[pngData writeToFile:[[[exportURL path] stringByAppendingPathComponent:@"Target"] 
													stringByAppendingPathExtension:@"png"] 
				  atomically:NO];
		
		[targetImagePool release];
	}
	
	if ([exportSettings includeTilePopUps])
		[[NSFileManager defaultManager] copyPath:[[NSBundle mainBundle] pathForImageResource:@"Loading"] 
										  toPath:[[exportURL path] stringByAppendingPathComponent:@"Loading.png"] 
										 handler:nil];
	
	tilesHTML = [[NSMutableString string] retain];
	areasHTML = [[NSMutableString string] retain];
	thumbnailNumbers = [[NSMutableDictionary dictionary] retain];
	thumbnailCount = 0;
	
	return nil;
}


- (id)fillTileWithColor:(NSColor *)fillColor 
		  clippedToPath:(NSBezierPath *)clipPath
{
	CGContextSaveGState(cgContext);
		
			// Set the clip path.
		CGPathRef	cgClipPath = [clipPath quartzPath];
		CGContextAddPath(cgContext, cgClipPath);
		CGContextClip(cgContext);
		CGPathRelease(cgClipPath);
		
			// Fill the path with the specified color.
		NSColor		*rgbColor = [fillColor blendedColorWithFraction:0.0 ofColor:[NSColor blackColor]];
		float		colorComponents[4] = {[rgbColor redComponent], 
										  [rgbColor greenComponent], 
										  [rgbColor blueComponent], 
										  [rgbColor alphaComponent]};
		CGContextSetFillColor(cgContext, colorComponents);
		NSRect		clipBounds = [clipPath bounds];
		CGContextFillRect(cgContext, CGRectMake(NSMinX(clipBounds), NSMinY(clipBounds), NSWidth(clipBounds), NSHeight(clipBounds)));
	
	CGContextRestoreGState(cgContext);
	
	return nil;
}


- (id)fillTileWithImage:(NSImage *)image 
		 withIdentifier:(NSString *)imageIdentifier 
			 fromSource:(id<MacOSaiXImageSource>)imageSource 
		centeredAtPoint:(NSPoint)centerPoint 
			   rotation:(float)imageRotation 
		  clippedToPath:(NSBezierPath *)clipPath 
				opacity:(float)opacity
{
		// Get a bitmap image rep from the image.
	NSBitmapImageRep	*bitmapRep = nil;
	NSEnumerator		*imageRepEnumerator = [[image representations] objectEnumerator];
	NSImageRep			*imageRep = nil;
	while (!bitmapRep && (imageRep = [imageRepEnumerator nextObject]))
		if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
			bitmapRep = (NSBitmapImageRep *)imageRep;
	// TODO: if no bitmap rep then lock focus and grab one
	
		// Convert the NSBitmapImageRep to a CGImage.
	CGDataProviderRef	cgDataProvider = CGDataProviderCreateWithData(NULL, 
																	  [bitmapRep bitmapData], 
																	  [bitmapRep bytesPerRow] * 
																		[bitmapRep pixelsHigh], 
																	  NULL);
	CGBitmapInfo		cgBitmapInfo = ([bitmapRep hasAlpha] ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone);
	CGImageRef			cgTileImage = CGImageCreate([bitmapRep pixelsWide], 
													[bitmapRep pixelsHigh], 
													[bitmapRep bitsPerSample], 
													[bitmapRep bitsPerPixel], 
													[bitmapRep bytesPerRow], 
													cgColorSpace, 
													cgBitmapInfo, 
													cgDataProvider, 
													NULL, 
													FALSE,
													kCGRenderingIntentDefault);
	
	CGContextSaveGState(cgContext);
		
			// Set the clip path.
		CGPathRef	cgClipPath = [clipPath quartzPath];
		CGContextAddPath(cgContext, cgClipPath);
		CGContextClip(cgContext);
		CGPathRelease(cgClipPath);
		
			// Set the rotation.  (negated and converted to radians)
		CGAffineTransform	cgRotationTransform = CGAffineTransformMakeTranslation(centerPoint.x, centerPoint.y);
		cgRotationTransform = CGAffineTransformRotate(cgRotationTransform, -imageRotation / 360.0 * M_PI * 2.0);
		cgRotationTransform = CGAffineTransformTranslate(cgRotationTransform, -centerPoint.x, -centerPoint.y);
		CGContextConcatCTM(cgContext, cgRotationTransform);
		
			// Draw the image.
		CGRect		cgTileRect = CGRectMake(centerPoint.x - [image size].width / 2.0, 
											centerPoint.y - [image size].height / 2.0, 
											[image size].width, 
											[image size].height);
		CGContextSetAlpha(cgContext, opacity);
		CGContextDrawImage(cgContext, cgTileRect, cgTileImage);
		
	CGContextRestoreGState(cgContext);
	
	CGImageRelease(cgTileImage);
	CGDataProviderRelease(cgDataProvider);
	
	if ([exportSettings includeTilePopUps])
	{
		// Create the HTML and thumbnail image to display the pop-up.
		id<NSObject,NSCoding,NSCopying>	imageUID = [imageSource universalIdentifierForIdentifier:imageIdentifier];
		int								thumbnailNumber = [[thumbnailNumbers objectForKey:imageUID] intValue];
		
		if (thumbnailNumber == 0)
		{
			// Create a thumbnail for this image.
			
			thumbnailNumber = ++thumbnailCount;
			[thumbnailNumbers setObject:[NSNumber numberWithInt:thumbnailNumber] forKey:imageUID];
			
			NSString	*description = [imageSource descriptionForIdentifier:imageIdentifier];
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
				NSBitmapImageRep	*bitmapRep = nil;
				[thumbnailImage lockFocus];
					bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, newSize.width, newSize.height)] autorelease];
				[thumbnailImage unlockFocus];
				NSData		*bitmapData = [bitmapRep representationUsingType:NSJPEGFileType properties:nil];
				[bitmapData writeToFile:[NSString stringWithFormat:@"%@/%d.jpg", [exportURL path], thumbnailNumber] 
							 atomically:NO];
				tileImageURL = [NSString stringWithFormat:@"%d.jpg", thumbnailNumber];
			}
			[tilesHTML appendFormat:@"tiles[%d] = new tile('%@', '%@');\n", thumbnailNumber, tileImageURL, description];
		}
		
		NSString	*contextURL = [[imageSource contextURLForIdentifier:imageIdentifier] absoluteString];
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform scaleBy:(float)[exportSettings width] / [[exportSettings targetImage] size].width];
		NSRect		clipBounds = [[transform transformBezierPath:clipPath] bounds];
		[areasHTML appendFormat:@"\t<area shape='rect' coords='%d,%d,%d,%d' %@ " 
								@"onmouseover='showTile(event,%d)' onmouseout='hideTile()'>\n", 
								(int)NSMinX(clipBounds), (int)([exportSettings height] - NSMaxY(clipBounds)), 
								(int)NSMaxX(clipBounds), (int)([exportSettings height] - NSMinY(clipBounds)), 
								(contextURL ? [NSString stringWithFormat:@"href='%@'", contextURL] : @""),
								thumbnailNumber];
	}

	return nil;
}


- (id)closeFile
{
	NSString		*error = nil;
	int				exportWidth = [exportSettings width], 
					exportHeight = [exportSettings height];
	
		// Convert the mosaic image to PNG and save it to the folder.
	if (cgImageDest)
	{
		CGDataProviderRef	cgDataProvider = CGDataProviderCreateWithData(NULL, bitmapBuffer, exportWidth * exportHeight * 4, NULL);
		CGImageRef			cgMosaicImage = CGImageCreate(exportWidth, 
														  exportHeight, 
														  8, 
														  32, 
														  exportWidth * 4, 
														  cgColorSpace, 
														  kCGImageAlphaPremultipliedLast, 
														  cgDataProvider, 
														  NULL, 
														  FALSE,
														  kCGRenderingIntentDefault);
		CGImageDestinationAddImage(cgImageDest, cgMosaicImage, NULL);
		CGImageDestinationFinalize(cgImageDest);
		
		CGImageRelease(cgMosaicImage);
		CGDataProviderRelease(cgDataProvider);
		CFRelease(cgImageDest);
	}
	else
	{
		NSBitmapImageRep		*exportRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bitmapBuffer 
																					 pixelsWide:exportWidth 
																					 pixelsHigh:exportHeight 
																				  bitsPerSample:8 
																				samplesPerPixel:4 
																					   hasAlpha:YES 
																					   isPlanar:NO 
																				 colorSpaceName:NSDeviceRGBColorSpace 
																					bytesPerRow:0 
																				   bitsPerPixel:0];
		NS_DURING
			[exportRep setSize:NSMakeSize(exportWidth, exportHeight)];
			
			NSData	*pngData = [exportRep representationUsingType:NSPNGFileType properties:nil];
			[pngData writeToFile:[[exportURL path] stringByAppendingPathComponent:@"Mosaic.png"] atomically:YES];
		NS_HANDLER
			error = [NSString stringWithFormat:NSLocalizedString(@"Could not convert the mosaic to PNG format.  (%@)", @""), 
											   [localException reason]];
		NS_ENDHANDLER
		
		[exportRep release];
	}
	
	CGContextRelease(cgContext);
	CGColorSpaceRelease(cgColorSpace);
	
	free(bitmapBuffer);
	bitmapBuffer = nil;
	
		// Build the web page itself.
	NSBundle		*exporterBundle = [NSBundle bundleForClass:[self class]];
	NSString		*export1HTMLPath = [exporterBundle pathForResource:@"Export1" ofType:@"html"];
	NSMutableString	*exportHTML = [NSMutableString stringWithContentsOfFile:export1HTMLPath];
	[exportHTML appendString:tilesHTML];
	NSString		*export2HTMLPath = [exporterBundle pathForResource:@"Export2" ofType:@"html"];
	[exportHTML appendString:[NSString stringWithContentsOfFile:export2HTMLPath]];
	NSString		*export3HTMLPath = nil;
	if ([exportSettings includeTargetImage])
		export3HTMLPath = [exporterBundle pathForResource:@"Export3+Target" ofType:@"html"];
	else
		export3HTMLPath = [exporterBundle pathForResource:@"Export3" ofType:@"html"];
	[exportHTML appendString:[NSString stringWithContentsOfFile:export3HTMLPath]];
	NSString		*export4HTMLPath = [exporterBundle pathForResource:@"Export4" ofType:@"html"];
	[exportHTML appendString:[NSString stringWithContentsOfFile:export4HTMLPath]];
	[exportHTML appendString:areasHTML];
	NSString		*export5HTMLPath = [exporterBundle pathForResource:@"Export5" ofType:@"html"];
	[exportHTML appendString:[NSString stringWithContentsOfFile:export5HTMLPath]];
	[exportHTML writeToFile:[[exportURL path] stringByAppendingPathComponent:@"index.html"] atomically:NO];
	
	[tilesHTML release];
	tilesHTML = nil;
	[areasHTML release];
	areasHTML = nil;
	[thumbnailNumbers release];
	thumbnailNumbers = nil;
	
	exportSettings = nil;
	[exportURL release];
	exportURL = nil;
	
	return error;
}


- (id)openFileInExternalViewer:(NSURL *)url
{
	NSString	*error = nil, 
				*htmlPath = [[url path] stringByAppendingPathComponent:@"index.html"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:htmlPath])
		error = NSLocalizedString(@"The web page could not be found.", @"");
	else if (![[NSWorkspace sharedWorkspace] openFile:htmlPath])
		error = NSLocalizedString(@"The web page could not be opened.", @"");
	
	return error;
}


@end
