//
//  MacOSaiXImageMatcher.m
//  MacOSaiX
//
//  Created by Frank Midgley on 8/28/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatcher.h"


static MacOSaiXImageMatcher	*sharedMatcher = nil;


@implementation MacOSaiXImageMatcher


+ (MacOSaiXImageMatcher *)sharedMatcher
{
	if (!sharedMatcher)
		sharedMatcher = [[MacOSaiXImageMatcher alloc] init];
	
	return sharedMatcher;
}


- (float)compareImageRep:(NSBitmapImageRep *)bitmapRep1
				withMask:(NSBitmapImageRep *)maskRep
			  toImageRep:(NSBitmapImageRep *)bitmapRep2
		    previousBest:(float)valueToBeat
{
	float			matchValue = 0.0;
	int				bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2, maskBytesPerPixel, maskBytesPerRow;
	float			pixelCount = 0, pixelsLeft;
	int				x, y, x_size, y_size;
	unsigned char	*bitmap1, *bitmap2, *maskBitmap;
	
	if (!bitmapRep1 || !bitmapRep2 || [bitmapRep1 pixelsWide] != [bitmapRep1 pixelsWide] || 
		[bitmapRep1 pixelsHigh] != [bitmapRep1 pixelsHigh])
		[NSException raise:@"Invalid bitmap(s)" format:@"The bitmaps to compare are not the same size"];
	
		// Scale the 0.0-1.0 value back to our internal scale to make calculation faster.
	valueToBeat *= (255.0 * 255.0 * 9.0);
	
		// the size of bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of bitmapRep centered in imageRep will be ignored
	
	bitmap1 = [bitmapRep1 bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
	bytesPerPixel1 = [bitmapRep1 hasAlpha] ? 4 : 3;
	bytesPerRow1 = [bitmapRep1 bytesPerRow];
	bitmap2 = [bitmapRep2 bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
	bytesPerPixel2 = [bitmapRep2 hasAlpha] ? 4 : 3;
	bytesPerRow2 = [bitmapRep2 bytesPerRow];
	if (maskRep)
	{
		maskBitmap = [maskRep bitmapData];
		maskBytesPerPixel = [maskRep hasAlpha] ? 4 : 3;
		maskBytesPerRow = [maskRep bytesPerRow];
	}

		// Add up the differences of all the pixels in the two bitmaps.
	x_size = [bitmapRep1 size].width; y_size = [bitmapRep1 size].height;
	pixelsLeft = x_size * y_size;
	for (x = 0; x < x_size; x++)
	{
		for (y = 0; y < y_size; y++)
		{
			unsigned char	*bitmap1_off = bitmap1 + x * bytesPerPixel1 + y * bytesPerRow1,
							*bitmap2_off = bitmap2 + x * bytesPerPixel2 + y * bytesPerRow2,
							*mask_off = maskBitmap + x * maskBytesPerPixel + y * maskBytesPerRow;
			int				redDiff = *bitmap1_off - *bitmap2_off, 
							greenDiff = *(bitmap1_off + 1) - *(bitmap2_off + 1), 
							blueDiff = *(bitmap1_off + 2) - *(bitmap2_off + 2);
			float			maskValue = (maskRep ? ((*mask_off) / 255.0) : 1.0);
#if 1
				// Use the Riemersma metric (courtesy of Dr. Dobbs 11/2001 pg. 58)
			float			redAverage = (*bitmap1_off + *bitmap2_off) / 2.0;
			matchValue += ((2.0 + redAverage / 255.0) * redDiff * redDiff + 
						   4 * greenDiff * greenDiff + 
						   (2 + (255.0 - redAverage) / 255.0) * blueDiff * blueDiff)
						   * maskValue; // weighted by alpha value from mask
#else
				// Do a direct colorspace calculation.
			matchValue += (redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff) * maskValue;
#endif
			pixelCount += maskValue;
		}
		pixelsLeft -= y_size;
		
		// Optimization: the lower the matchValue the better so if it's already greater 
		// than the previous best then it's no use going any further.
		if (matchValue / (float)(pixelCount + pixelsLeft) > valueToBeat)
			return 1.0;
	}

		// Average the value per pixel and scale into the 0-1 range.
		// A pixel count of zero means that the image was completely transparent and we shouldn't use it.
	matchValue = (pixelCount == 0 ? 1.0 : matchValue / pixelCount / (255.0 * 255.0 * 9.0));
	
	return matchValue;
}


@end
