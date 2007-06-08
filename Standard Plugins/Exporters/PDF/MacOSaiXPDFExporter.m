//
//  MacOSaiXPDFExporter.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPDFExporter.h"

#import "MacOSaiXPDFExportSettings.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXPDFExporter


- (BOOL)exportString:(NSString *)exportString
{
	BOOL	success = NO;
	NSData	*exportData = [exportString dataUsingEncoding:NSASCIIStringEncoding];
	
	if (exportData)
	{
		NS_DURING
			[exportFileHandle writeData:[exportString dataUsingEncoding:NSASCIIStringEncoding]];
			success = YES;
		NS_HANDLER
			#ifdef DEBUG
				NSLog(@"Could not export PDF string: ", [localException reason]);
			#endif
		NS_ENDHANDLER
	}
		
	return success;
}


- (BOOL)exportFormat:(NSString *)exportFormat, ...
{
	NSString	*exportString = nil;
	va_list		argList;
	
	va_start(argList, exportFormat);
	exportString = [[[NSString alloc] initWithFormat:exportFormat arguments:argList] autorelease];
	va_end(argList);
	
	return [self exportString:exportString];
}


- (long)reserveAnObjectID
{
	[objectOffsets addObject:[NSNull null]];
	
	return objectCount++;
}


- (BOOL)exportObjectWithID:(long)objectID body:(NSString *)objectBody
{
	BOOL				success = NO;
	unsigned long long	objectOffset = [exportFileHandle offsetInFile];
	
	if ([self exportFormat:@"%d 0 obj\n"\
							"%@"\
							"endobj\n\n", objectID, objectBody])
	{
		if (objectID < [objectOffsets count])
			[objectOffsets replaceObjectAtIndex:objectID withObject:[NSNumber numberWithUnsignedLongLong:objectOffset]];
		else
			[objectOffsets addObject:[NSNumber numberWithUnsignedLongLong:objectOffset]];
		
		success = YES;
	}
	
	return success;
}


- (BOOL)exportObjectWithID:(long)objectID format:(NSString *)objectFormat, ...
{
	NSString			*objectBody = nil;
	va_list				argList;
	
	va_start(argList, objectFormat);
	objectBody = [[[NSString alloc] initWithFormat:objectFormat arguments:argList] autorelease];
	va_end(argList);
	
	return [self exportObjectWithID:objectID body:objectBody];
}


- (long)exportObjectWithFormat:(NSString *)objectFormat, ...
{
	long		objectID = [self reserveAnObjectID];
	NSString	*objectBody = nil;
	va_list		argList;
	
	va_start(argList, objectFormat);
	objectBody = [[[NSString alloc] initWithFormat:objectFormat arguments:argList] autorelease];
	va_end(argList);
	
	if (![self exportObjectWithID:objectID body:objectBody])
		objectID = -1;
	
	return objectID;
}


- (NSNumber *)exportImage:(NSImage *)image
{
	NSNumber			*imageNumber = nil;
	
		// Get a bitmap image rep from the image.
	NSBitmapImageRep	*bitmapRep = nil;
	NSEnumerator		*imageRepEnumerator = [[image representations] objectEnumerator];
	NSImageRep			*imageRep = nil;
	while (!bitmapRep && (imageRep = [imageRepEnumerator nextObject]))
		if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
			bitmapRep = (NSBitmapImageRep *)imageRep;
	// TODO: if no bitmap rep then lock focus and grab one
	
	// TBD: pass any NSPDFImageRep straight through?
	
	NSString	*imageStream = [bitmapRep ascii85Stream];
	long		objectID = [self exportObjectWithFormat:@" << /Type /XObject\n"\
													     "    /Subtype /Image\n"\
													     "    /Width %d\n"\
													     "    /Height %d\n"\
													     "    /ColorSpace /DeviceRGB\n"\
													     "    /BitsPerComponent 8\n"\
													     "    /Length %u\n"\
													     "    /Filter /ASCII85Decode >>\n"\
													     "stream\n"\
													     "%@\n"\
													     "endstream\n", (int)[bitmapRep size].width, (int)[bitmapRep size].height, (unsigned long)[imageStream length], imageStream];
	if (objectID >= 0)
		imageNumber = [NSNumber numberWithLong:objectID];
	
	return imageNumber;
}


- (id)openFileAtURL:(NSURL *)url 
	   withSettings:(id<MacOSaiXExportSettings>)settings
{
	NSString		*error = nil;
	NSString		*exportPath = [url path];
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	
	exportSettings = (MacOSaiXPDFExportSettings *)settings;
	
	if (([fileManager fileExistsAtPath:exportPath] && ![fileManager removeFileAtPath:exportPath handler:nil]) ||
		![fileManager createFileAtPath:exportPath contents:nil attributes:nil])
		error = NSLocalizedString(@"Could not create the export file", @"");
	else
	{
		exportFileHandle = [[NSFileHandle fileHandleForWritingAtPath:exportPath] retain];
		
			// Start with the PDF header.
		if (![self exportFormat:@"%%PDF-1.4\n\n"])
			error = NSLocalizedString(@"Could not add the PDF version to the file", @"");
		else
		{
			float	pointWidth = [exportSettings width] * 72.0, 
					pointHeight = [exportSettings height] * 72.0;
			if ([exportSettings units] == cmUnits)
			{
				pointWidth *= 2.54;
				pointHeight *= 2.54;
			}
			
			NSSize	targetImageSize = [[exportSettings targetImage] size];
			
				// Set up the CTM to map the size of the target image to the size of the page's media box.
			contentStream = [[NSMutableString stringWithFormat:@"%f 0 0 %f 0 0 cm\n\n", pointWidth / targetImageSize.width, 
																						pointHeight / targetImageSize.height] retain];
			objectOffsets = [[NSMutableArray array] retain];
			imageIDs = [[NSMutableDictionary dictionary] retain];
			
				// Add the header objects.
			long	procSetID = [self exportObjectWithFormat:@"[/PDF /ImageC]\n"], 
					outlinesID = [self exportObjectWithFormat:@"<< /Type /Outlines\n"\
															   "   /Count 0\n"\
															   ">>\n"];
			contentsID = [self reserveAnObjectID];
			xObjectsID = [self reserveAnObjectID];
			
			long	pagesID = [self reserveAnObjectID], 
					pageID = [self exportObjectWithFormat:@"<< /Type /Page\n"\
														   "   /Parent %d 0 R\n"\
														   "   /MediaBox [0 0 %d %d]\n"\
														   "   /Contents %d 0 R\n"\
														   "   /Resources << /ProcSet %d 0 R\n"\
														   "                 /XObject %d 0 R>>\n"\
														   ">>\n", pagesID, (int)pointWidth, (int)pointHeight, contentsID, procSetID, xObjectsID];
			
			rootID = [self exportObjectWithFormat:@"<< /Type /Catalog\n"\
												   "   /Outlines %d 0 R\n"\
												   "   /Pages %d 0 R\n"\
												   ">>\n", outlinesID, pagesID];
			
			if (procSetID < 0 || outlinesID < 0 || pagesID < 0 || rootID < 0 || 
				![self exportObjectWithID:pagesID format:@"<< /Type /Pages\n"\
														  "   /Kids [ %d 0 R ]\n"\
														  "   /Count 1\n"\
														  ">>\n", pageID])
				error = NSLocalizedString(@"Could not add the PDF header to the file", @"");
		}
		
		if (error)
		{
			[contentStream release];
			contentStream = nil;
			[objectOffsets release];
			objectOffsets = nil;
			[exportFileHandle closeFile];
			[exportFileHandle release];
			exportFileHandle = nil;
		}
	}
	
	return error;
}


- (id)fillTileWithColor:(NSColor *)fillColor 
		  clippedToPath:(NSBezierPath *)clipPath
{
	NSString	*error = nil;
	NSColor		*rgbColor = [fillColor blendedColorWithFraction:0.0 ofColor:[NSColor blackColor]];
	
	// TBD: handle pattern colors?
	
	if (!rgbColor)
		error = NSLocalizedString(@"Could not get the components of a tile's fill color.", @"");
	else
		[contentStream appendFormat:@"%@ %@ %@ rg\n"\
									@"%@"\
									@"f\n\n", 
									[NSString stringWithFloat:[rgbColor redComponent]], 
									[NSString stringWithFloat:[rgbColor greenComponent]], 
									[NSString stringWithFloat:[rgbColor blueComponent]], 
									[clipPath pdfPath]];
	
	return error;
}


- (NSNumber *)imageIDForImage:(NSImage *)image
			   withIdentifier:(NSString *)imageIdentifier 
				   fromSource:(id<MacOSaiXImageSource>)imageSource 
{
	NSDictionary	*imageKey = [NSDictionary dictionaryWithObjectsAndKeys:
									imageIdentifier, @"Image Identifier", 
									[NSValue valueWithPointer:imageSource], @"Image Source Pointer", 
									nil];
	NSNumber		*imageID = [imageIDs objectForKey:imageKey];
	
	if (!imageID)
	{
		imageID = [self exportImage:image];
		
		if (imageID)
			[imageIDs setObject:imageID forKey:imageKey];
	}
	
	return imageID;
}


- (id)fillTileWithImage:(NSImage *)image 
		 withIdentifier:(NSString *)imageIdentifier 
			 fromSource:(id<MacOSaiXImageSource>)imageSource 
		centeredAtPoint:(NSPoint)centerPoint 
			   rotation:(float)imageRotation 
		  clippedToPath:(NSBezierPath *)clipPath
{
	NSString	*error = nil;
	NSNumber	*imageID = [self imageIDForImage:image withIdentifier:imageIdentifier fromSource:imageSource];
	
	if (!imageID)
		error = NSLocalizedString(@"Could not save a tile's image to the PDF.", @"");
	else
		[contentStream appendFormat:@"q\n"\
									 " %@ W n\n"\
									 " %f 0 0 %f %f %f cm\n"\
									 " /Image%@ Do\n"\
									 "Q\n\n", [clipPath pdfPath], [image size].width, [image size].height, centerPoint.x - [image size].width / 2.0, centerPoint.y - [image size].height / 2.0, imageID];
	
	// TODO: Set the rotation.
	
	return error;
}


- (id)closeFile
{
	NSString		*error = nil;
	
		// Export the XObjects dictionary.
	NSMutableString	*xObjectsStream = [NSMutableString stringWithString:@" <<"];
	NSEnumerator	*imageIDEnumerator = [imageIDs objectEnumerator];
	NSString		*imageID = nil;
	while (imageID = [imageIDEnumerator nextObject])
		[xObjectsStream appendFormat:@" /Image%@ %@ 0 R\n   ", imageID, imageID];
	[xObjectsStream appendString:@" >>\n"];
	if (![self exportObjectWithID:xObjectsID format:xObjectsStream])
		error = NSLocalizedString(@"Could not save the image names to the file.", @"");
	else
	{
		if (![self exportObjectWithID:contentsID format:@" << /Length %d >>\n"\
														 "stream\n"\
														 "%@"\
														 "endstream\n", [contentStream length] - 1, contentStream])
			error = NSLocalizedString(@"Could not save the drawing instructions to the file.", @"");
		else
		{
			NSMutableString		*xrefStream = [NSMutableString string];
			unsigned long		objectID;
			for (objectID = 0; objectID < objectCount; objectID++)
				[xrefStream appendFormat:@"%010qu 00000 n \n", [[objectOffsets objectAtIndex:objectID] unsignedLongLongValue]];
			
			unsigned long long	xrefOffset = [exportFileHandle offsetInFile];
			
			if (![self exportFormat:@"xref\n"\
									 "0 %d\n"\
									 "%@\n"\
									 "trailer\n"\
									 " << /Size %d\n"\
									 "    /Root %d 0 R\n"\
									 " >>\n"\
									 "startxref\n"\
									 "%qu\n"\
									 "%%%%EOF", objectCount, xrefStream, objectCount, rootID, xrefOffset])
				error = NSLocalizedString(@"Could not save the trailer to the file.", @"");
		}
	}
	
	[contentStream release];
	contentStream = nil;
	[objectOffsets release];
	objectOffsets = nil;
	
	[exportFileHandle closeFile];
	[exportFileHandle release];
	exportFileHandle = nil;
	
	exportSettings = nil;
	
	return error;
}


@end


@implementation NSBezierPath (MacOSaiXPDFExporter)


- (NSString *)pdfPath
{
    int				i, numElements = [self elementCount];
    NSMutableString	*pdfPath = [NSMutableString string];
	NSPoint			points[3];
	
		// Iterate over the elements of the path.
	for (i = 0; i < numElements; i++) 
	{
		switch ([self elementAtIndex:i associatedPoints:points]) 
		{
			case NSMoveToBezierPathElement:
				[pdfPath appendFormat:@"%g %g m\n", points[0].x, points[0].y];
				break;
				
			case NSLineToBezierPathElement:
				[pdfPath appendFormat:@"%g %g l\n", points[0].x, points[0].y];
				break;
				
			case NSCurveToBezierPathElement:
				[pdfPath appendFormat:@"%g %g %g %g %g %g c\n", 
									  points[0].x, points[0].y, 
									  points[1].x, points[1].y, 
									  points[2].x, points[2].y];
				break;
				
			case NSClosePathBezierPathElement:
				[pdfPath appendString:@"h\n"];
				break;
		}
	}
	
    return pdfPath;
}


@end


@implementation NSBitmapImageRep (MacOSaiXPDFExporter)


- (NSString *)ascii85Stream
{
	NSMutableString		*imageStream = [NSMutableString string];
	unsigned char		*bytes = [self bitmapData];
	int					pixelsWide = [self pixelsWide], 
						pixelsHigh = [self pixelsHigh], 
						bytesPerRow = [self bytesPerRow], 
						x = 0, 
						y = 0, 
						c = 0, 
						byteCount = 0;
	unsigned long long	metaByte = 0;
	unsigned char		*rowPointer = bytes;
	BOOL				skipAlphaByte = [self hasAlpha];
	
	for (y = 0; y < pixelsHigh; y++)
	{
		unsigned char		*pixelPointer = rowPointer;
		
		for (x = 0; x < pixelsWide; x++)
		{
			for (c = 0; c < 3; c++)
			{
				metaByte = metaByte * 256 + *(pixelPointer++);
				byteCount++;
				
				if (byteCount == 4)
				{
					unsigned char		c1 = metaByte / (85*85*85*85);
					metaByte -= (long long)c1*85*85*85*85;
					unsigned char		c2 = metaByte / (85*85*85);
					metaByte -= (long)c2*85*85*85;
					unsigned char		c3 = metaByte / (85*85);
					metaByte -= c3*85*85;
					unsigned char		c4 = metaByte / 85, 
										c5 = metaByte - c4*85;
					
					if (c1 > 84 || c2 > 84 || c3 > 84 || c4 > 84 || c5 > 84)
						NSLog(@"oops");
					
					if (c1 != 0 || c2 != 0 || c3 != 0 || c4 != 0 || c5 != 0)
						[imageStream appendFormat:@"%c%c%c%c%c", c1 + 33, c2 + 33, c3 + 33, c4 + 33, c5 + 33];
					else
						[imageStream appendString:@"z"];
					
					metaByte = 0;
					byteCount = 0;
				}
			}
			
			if (skipAlphaByte)
				pixelPointer++;
		}
		
		rowPointer += bytesPerRow;
	}
	
	if (byteCount > 0)
	{
			// Pad with zeros.
		if (byteCount == 1)
			metaByte *= 256*256*256;
		else if (byteCount == 2)
			metaByte *= 256*256;
		else if (byteCount == 3)
			metaByte *= 256;
		
		unsigned char		c1 = metaByte / (85*85*85*85);
		metaByte -= (long long)c1*85*85*85*85;
		unsigned char		c2 = metaByte / (85*85*85);
		metaByte -= (long)c2*85*85*85;
		unsigned char		c3 = metaByte / (85*85);
		metaByte -= c3*85*85;
		unsigned char		c4 = metaByte / 85;
		
		if (byteCount == 1)
			[imageStream appendFormat:@"%c%c~>", c1 + 33, c2 + 33];
		else if (byteCount == 2)
			[imageStream appendFormat:@"%c%c%c~>", c1 + 33, c2 + 33, c3 + 33];
		else if (byteCount == 3)
			[imageStream appendFormat:@"%c%c%c%c~>", c1 + 33, c2 + 33, c3 + 33, c4 + 33];
	}
	
	return imageStream;
}


@end
