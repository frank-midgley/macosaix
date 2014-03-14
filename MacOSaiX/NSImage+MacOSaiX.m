//
//  NSImage+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 11/13/04.
//  Copyright 2004 Frank M. Midgley. All rights reserved.
//

#import "NSImage+MacOSaiX.h"

#import "MacOSaiXBitmapImageRep.h"


@implementation NSImage (MacOSaiX)


- (NSImage *)copyWithLargestDimension:(int)largestDimension
{
	NSImage	*copy = nil;
	NSSize	copySize, originalSize = [self size];
	
	if (originalSize.width > originalSize.height)
		copySize = NSMakeSize(largestDimension, round(originalSize.height * largestDimension / originalSize.width));
	else
		copySize = NSMakeSize(round(originalSize.width * largestDimension / originalSize.height), largestDimension);
	
	if (copySize.width >= 1.0 && copySize.height >= 1.0)
	{
		NSRect				copyRect = NSMakeRect(0.0, 0.0, copySize.width, copySize.height);
		
		copy = [[NSImage alloc] initWithSize:copySize];
		
//		NSBitmapImageRep	*bitmapRep = nil;
		BOOL				haveFocus = NO;
		while (!haveFocus)	// && ???
		{
			NS_DURING
				[copy lockFocus];
				haveFocus = YES;
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Couldn't lock focus on image copy: %@", localException);
				#endif
				
				[copy release];
				copy = nil;
			NS_ENDHANDLER
		}
		
		if (haveFocus)
		{
			NSRect	imageBounds = NSMakeRect(0.0, 0.0, originalSize.width, originalSize.height);
			
			[[NSColor clearColor] set];
			NSRectFill(imageBounds);
			
			[self drawInRect:copyRect 
					fromRect:imageBounds 
				   operation:NSCompositeSourceOver 
					fraction:1.0];
//			bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:copyRect] autorelease];
			[copy unlockFocus];
			
			NSData	*bitmapData = [copy TIFFRepresentation];
			[copy removeRepresentation:[[copy representations] lastObject]];
			[copy addRepresentation:[MacOSaiXBitmapImageRep imageRepWithData:bitmapData]];	// bitmapRep
		}
		else
		{
			#ifdef DEBUG
				NSLog(@"Couldn't create cached thumbnail image.");
			#endif
			
			[copy release];
			copy = nil;
		}
	}
	
	return copy;
}


- (MacOSaiXBitmapImageRep *)reasonablyFullSizedBitmapRep
{
	MacOSaiXBitmapImageRep	*reasonablyFullSizedBitmapRep = nil;
	
	if ([self size].width > 512 || [self size].height > 512)
	{
			// Don't bother caching full sized massive images.  They will likely never be needed and can clobber the cache.  A single 5000 x 5000 pixel bitmap is ~95MB!  Reducing to 512 x 512 pixels drops that to 1MB and still gives you an image that scales well to full screen if needed.
		NSImage	*copy = [self copyWithLargestDimension:512];
		
		reasonablyFullSizedBitmapRep = [[[[copy representations] objectAtIndex:0] retain] autorelease];
		
		#ifdef DEBUG
//			NSLog(@"Saved %.1f MB caching", ([self size].width * [self size].height - [copy size].width * [copy size].height) / 512.0 / 512.0);
		#endif
			
		[copy release];
	}
	else
	{
			// Check if the image already has a rep we can use.
		NSEnumerator		*existingRepEnumerator = [[self representations] objectEnumerator];
		NSImageRep			*existingRep = nil;
		NSRect				fullSizeRect = NSZeroRect;
		while (existingRep = [existingRepEnumerator nextObject])
		{
//			if ([existingRep isKindOfClass:[NSBitmapImageRep class]] && 
//				(!reasonablyFullSizedBitmapRep || [existingRep pixelsWide] > [reasonablyFullSizedBitmapRep pixelsWide]))
//				reasonablyFullSizedBitmapRep = (NSBitmapImageRep *)existingRep;
			
			if ([existingRep pixelsWide] > NSWidth(fullSizeRect))
				fullSizeRect = NSMakeRect(0.0, 0.0, [existingRep pixelsWide], [existingRep pixelsHigh]);
		}
		
		if (!reasonablyFullSizedBitmapRep && NSWidth(fullSizeRect) >= 1.0 && NSHeight(fullSizeRect) >= 1.0)
			reasonablyFullSizedBitmapRep = [MacOSaiXBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
	}
	
	return reasonablyFullSizedBitmapRep;
}


@end
