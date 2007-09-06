//
//  MacOSaiXBitmapExporter.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapExporter.h"

#import "MacOSaiXBitmapExportSettings.h"
#import "NSBezierPath+MacOSaiX.h"
#include <stdlib.h>


@implementation MacOSaiXBitmapExporter
	

- (id)createFileAtURL:(NSURL *)url 
		 withSettings:(id<MacOSaiXExportSettings>)settings
{
	exportURL = [url retain];
	exportSettings = (MacOSaiXBitmapExportSettings *)settings;
	
	int						exportWidth = [exportSettings pixelWidth], 
							exportHeight = [exportSettings pixelHeight];
	
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
	
//	CGDataProviderRef		cgDataProvider = NULL;
	
		// Start with an entirely clear bitmap.
	float					clearColorComponents[4] = {0.0, 0.0, 0.0, 0.0};
	CGContextSetFillColor(cgContext, clearColorComponents);
	CGContextFillRect(cgContext, CGRectMake(0.0, 0.0, exportWidth, exportHeight));
	
		// Create a transform to scale from the target image size to the export size.
	NSSize					targetImageSize = [[exportSettings targetImage] size];
	CGContextConcatCTM(cgContext, CGAffineTransformMakeScale(exportWidth / targetImageSize.width, 
															 exportHeight / targetImageSize.height));
	
	// TODO: #ifdef out for i386 build
	// if (CGImageDestinationCreateWithURL)
	{
		CFStringRef	imageType = kUTTypePNG;
		
		if ([[exportSettings format] isEqualToString:@"JPEG"])
			imageType = kUTTypeJPEG;
		else if ([[exportSettings format] isEqualToString:@"JPEG 2000"])
			imageType = kUTTypeJPEG2000;
		else if ([[exportSettings format] isEqualToString:@"PNG"])
			imageType = kUTTypePNG;
		else if ([[exportSettings format] isEqualToString:@"TIFF"])
			imageType = kUTTypeTIFF;
		
		cgImageDest = CGImageDestinationCreateWithURL((CFURLRef)exportURL, imageType, 1, NULL);
	}
	
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
	
	return nil;
}


- (id)closeFile
{
	NSString				*error = nil;
	int						exportWidth = [exportSettings pixelWidth], 
							exportHeight = [exportSettings pixelHeight];
	
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
		NSBitmapImageFileType	exportImageType = NSJPEGFileType;
		NSMutableDictionary		*properties = [NSMutableDictionary dictionary];

		if ([[exportSettings format] isEqualToString:@"JPEG"])
			exportImageType = NSJPEGFileType;
		else if ([[exportSettings format] isEqualToString:@"PNG"])
			exportImageType = NSPNGFileType;
		else if ([[exportSettings format] isEqualToString:@"TIFF"])
		{
			exportImageType = NSTIFFFileType;
			[properties setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:NSImageCompressionMethod];
		}
		
			// Convert to the bitmap format
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
			float	scale = 72.0 / [exportSettings pixelsPerInch];
			[exportRep setSize:NSMakeSize(exportWidth * scale, exportHeight * scale)];
			
			NSData	*bitmapData = [exportRep representationUsingType:exportImageType properties:properties];
			[bitmapData writeToURL:exportURL atomically:YES];
		NS_HANDLER
			error = [NSString stringWithFormat:NSLocalizedString(@"Could not convert the mosaic to the requested format.  (%@)", @""), 
											   [localException reason]];
		NS_ENDHANDLER
		
		[exportRep release];
	}
	
	CGContextRelease(cgContext);
	CGColorSpaceRelease(cgColorSpace);
	
	free(bitmapBuffer);
	bitmapBuffer = nil;
	
	exportSettings = nil;
	[exportURL release];
	exportURL = nil;
	
	return error;
}


- (id)openFileInExternalViewer:(NSURL *)url
{
	NSString	*error = nil;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]])
		error = NSLocalizedString(@"The file could not be found.", @"");
	else if (![[NSWorkspace sharedWorkspace] openURL:url])
		error = NSLocalizedString(@"The file could not be opened.", @"");
	
	return error;
}


@end
