//
//  MacOSaiXBitmapImageRep.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/3/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapImageRep.h"

#import "MacOSaiXSourceImage.h"


@implementation MacOSaiXBitmapImageRep


- (void)imageRepWasAccessed
{
	lastAccessTickCount = TickCount();
}


- (UInt32)lastAccessTickCount
{
	return lastAccessTickCount;
}


- (void)setSourceImage:(MacOSaiXSourceImage *)image
{
	[sourceImage autorelease];
	sourceImage = [image retain];
}


- (MacOSaiXSourceImage *)sourceImage
{
	return sourceImage;
}


- (NSComparisonResult)compare:(id)otherObject
{
	NSSize	mySize = [self size], 
			otherSize = [otherObject size];
	float	myArea = mySize.width * mySize.height, 
			otherArea = otherSize.width * otherSize.height;
	
	if (myArea < otherArea)
		return NSOrderedAscending;
	else if (myArea > otherArea)
		return NSOrderedDescending;
	else
	{
		UInt32	otherTickCount = [otherObject lastAccessTickCount];
		
		if (lastAccessTickCount > otherTickCount)
			return NSOrderedAscending;
		else if (lastAccessTickCount < otherTickCount)
			return NSOrderedDescending;
		else
			return NSOrderedSame;
	}
}


// This was supposed to make -bitmapData faster (http://www.cocoabuilder.com/archive/message/cocoa/2008/5/26/208254) but it really slowed things down.
//- (void *)bitmapData
//{
//	void	*bitmapData = nil;
//	
//	if ([NSGraphicsContext respondsToSelector:@selector(graphicsContextWithGraphicsPort:flipped:)])
//	{
//		// Create the buffer by drawing to a CG bitmap context.
//		
//		size_t	bytesPerRow = [self pixelsWide] * 4, 
//				bitmapSize = [self pixelsHigh] * bytesPerRow;
//		
//		bitmapData = malloc(bitmapSize);
//		
//		CGColorSpaceRef		cgColorSpace = CGColorSpaceCreateDeviceRGB();
//		CGContextRef		cgContext = CGBitmapContextCreate(bitmapData, 
//															  [self pixelsWide], 
//															  [self pixelsHigh], 
//															  8, 
//															  bytesPerRow, 
//															  cgColorSpace, 
//															  ([self hasAlpha] ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast));
//		CGContextSetInterpolationQuality(cgContext, kCGInterpolationNone);
//		NSGraphicsContext	*nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:NO];
//		[NSGraphicsContext saveGraphicsState];
//			[NSGraphicsContext setCurrentContext:nsContext];
//			[self drawInRect:NSMakeRect(0.0, 0.0, [self pixelsWide], [self pixelsHigh])];
//		[NSGraphicsContext restoreGraphicsState];
//		CGContextRelease(cgContext);
//		CGColorSpaceRelease(cgColorSpace);
//		
//			// Put the buffer on the current auto-release pool.
//		[NSData dataWithBytesNoCopy:bitmapData length:bitmapSize freeWhenDone:YES];
//	}
//	
//	if (!bitmapData)
//		bitmapData = [super bitmapData];
//	
//	return bitmapData;
//}

	
- (unsigned char *)bitmapData
{
	void	*bitmapData = nil;
	
	if ([self pixelsWide] > 32 || [self pixelsHigh] > 32)
		bitmapData = [super bitmapData];
	else
	{
		if (cachedBitmapData)
			bitmapData = (void *)[cachedBitmapData bytes];
		else
		{
			bitmapData = [super bitmapData];
			
			if (bitmapData)
				cachedBitmapData = [[NSData dataWithBytes:bitmapData length:([self bytesPerRow] * [self pixelsHigh])] retain];
		}
	}
	
	return bitmapData;
}


- (void)dealloc
{
	[sourceImage release];
	[cachedBitmapData release];
	
	[super dealloc];
}


@end
