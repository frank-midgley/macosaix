//
//  MacOSaiXImageMatcher.m
//  MacOSaiX
//
//  Created by Frank Midgley on 8/28/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatcher.h"


#define USE_RIEMERSMA 0

#if USE_RIEMERSMA
	#define MAX_COLOR_DIFF (255.0 * 255.0 * 9.0)
#else
	#define MAX_COLOR_DIFF (255.0 * 255.0 * 3.0)
#endif

static MacOSaiXImageMatcher	*sharedMatcher = nil;

typedef struct pixelColor
{
	unsigned char	red, green, blue;
} pixelColor;


	// Return a value between 0.0 (no difference) and MAX_COLOR_DIFF (maximum difference).
float colorDifference(pixelColor color1, pixelColor color2)
{
	int			redDiff = color1.red - color2.red, 
				greenDiff = color1.green - color2.green, 
				blueDiff = color1.blue - color2.blue;
	
	#if USE_RIEMERSMA
			// Use the Riemersma metric (courtesy of Dr. Dobbs 11/2001 pg. 58)
		float	redAverage = (color1.red + color2.red) / 2.0;
		return ((2.0 + redAverage / 255.0) * redDiff * redDiff + 
			    4 * greenDiff * greenDiff + 
			    (2 + (255.0 - redAverage) / 255.0) * blueDiff * blueDiff);
	#else
			// Do a direct RGB colorspace calculation.
		return redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff;
	#endif
}


@implementation MacOSaiXImageMatcher


+ (MacOSaiXImageMatcher *)sharedMatcher
{
	if (!sharedMatcher)
		sharedMatcher = [[MacOSaiXImageMatcher alloc] init];
	
	return sharedMatcher;
}

- (NSData *)adjustedMaskForMaskRep:(NSBitmapImageRep *)maskRep ofImageRep:(NSBitmapImageRep *)imageRep
{
	unsigned char	adjustedMask[[maskRep pixelsHigh] * [maskRep pixelsWide]];
	unsigned char	*imageBytes = [imageRep bitmapData], 
					*maskBytes = [maskRep bitmapData];
	int				bytesPerPixel = [imageRep hasAlpha] ? 4 : 3, 
					bytesPerRow = [imageRep bytesPerRow], 
					maskBytesPerPixel = [maskRep hasAlpha] ? 4 : 3, 
					maskBytesPerRow = [maskRep bytesPerRow];
	int				startX, startY, pixelsWide = [imageRep size].width, pixelsHigh = [imageRep size].height;
	
	for (startX = 0; startX < pixelsWide; startX++)
		for (startY = 0; startY < pixelsHigh; startY++)
		{
			unsigned char	*imageOffset = imageBytes + startX * bytesPerPixel + startY * bytesPerRow,
							maskByte = *(maskBytes + startX * maskBytesPerPixel + startY * maskBytesPerRow);
//			pixelColor		startColor = {*imageOffset, *(imageOffset + 1), *(imageOffset + 2)};

#if 1
				// Alter the mask weight based on the start pixel's similarity to its neighbors.
				// The more dissimilar it is the less important it is to get a good match for that pixel.
//			float			totalDifference = 0.0;
//			int				neighborX, neighborY, neighborCount = 0;
//			for (neighborX = MAX(0, startX - 2); neighborX < MIN(pixelsWide, startX + 2); neighborX++)
//				for (neighborY = MAX(0, startY - 2); neighborY < MIN(pixelsHigh, startY + 2); neighborY++)
//					if (startX != neighborX || startY != neighborY)
//					{
//						unsigned char	*neighborOffset = imageBytes + neighborX * bytesPerPixel + neighborY * bytesPerRow;
//						pixelColor		neighborColor = {*neighborOffset, *(neighborOffset + 1), *(neighborOffset + 2)};
//						
//						totalDifference += colorDifference(startColor, neighborColor);
//						neighborCount++;
//					}
//			float			adjustment = (MAX_COLOR_DIFF - (totalDifference / neighborCount)) / MAX_COLOR_DIFF;
//			adjustedMask[startX + startY * pixelsWide] = (maskRep ? (float)maskByte : 255.0) * adjustment;
			adjustedMask[startX + startY * pixelsWide] = (maskRep ? (float)maskByte : 255.0);
#else			
				// Alter the mask weight based on the size of the color patch this pixel is in.
			NSMutableArray	*pointsInPatch = [NSMutableArray array], 
							*queue = [NSMutableArray arrayWithObject:[NSValue valueWithPoint:NSMakePoint(startX, startY)]];
			
			while ([queue count] > 0)
			{
				NSValue			pointValue = [queue objectAtIndex:0];
				int				x = [pointValue pointValue].x, 
								y = [pointValue pointValue].y;
				unsigned char	*bitmapOffset = imageBytes + x * bytesPerPixel + y * bytesPerRow;
				float			colorDiff = colorDifference(startRed, startGreen, startBlue,
															*bitmapOffset, *(bitmapOffset + 1), *(bitmapOffset + 2));
				
				if (colorDiff < MAX_COLOR_DIFF / 10.0)
				{
						// This point is in the starting point patch.
					[pointsInPatch addObject:pointValue];
					
						// Add any of the four neighbors of this point that aren't already part of 
						// the patch to the queue to be checked.
					if (x > 0)
					{
						NSValue	*value = [NSValue valueWithPoint:NSMakePoint(x - 1, y)];
						if (![pointsInPatch containsObject:value])
							[queue addObject:value];
					}
					if (x < pixelsWide - 1)
					{
						NSValue	*value = [NSValue valueWithPoint:NSMakePoint(x + 1, y)];
						if (![pointsInPatch containsObject:value])
							[queue addObject:value];
					}
					if (y > 0)
					{
						NSValue	*value = [NSValue valueWithPoint:NSMakePoint(x, y - 1)];
						if (![pointsInPatch containsObject:value])
							[queue addObject:value];
					}
					if (y < pixelsHigh - 1)
					{
						NSValue	*value = [NSValue valueWithPoint:NSMakePoint(x, y + 1)];
						if (![pointsInPatch containsObject:value])
							[queue addObject:value];
					}
				}
					
				[queue removeObjectAtIndex:0];
			}
			
			adjustedMask[startY][startX] = (maskRep ? (float)mask : 255.0) * ([pointsInPatch count] / pixelsWide / pixelsHigh);
#endif
		}
	
//	return [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **)adjustedMask 
//													pixelsWide:pixelsWide 
//													pixelsHigh:pixelsHigh 
//												 bitsPerSample:8 
//											   samplesPerPixel:1 
//													  hasAlpha:NO 
//													  isPlanar:NO 
//												colorSpaceName:NSCalibratedWhiteColorSpace 
//												   bytesPerRow:xSize 
//												  bitsPerPixel:8] autorelease];
	return [NSData dataWithBytes:adjustedMask length:pixelsWide * pixelsHigh];
}


- (float)compareImageRep:(NSBitmapImageRep *)bitmapRep1
				withMask:(NSBitmapImageRep *)maskRep
			  toImageRep:(NSBitmapImageRep *)bitmapRep2
		    previousBest:(float)valueToBeat
{
	if (!bitmapRep1 || !bitmapRep2 || 
		[bitmapRep1 pixelsWide] != [maskRep pixelsWide] || [bitmapRep1 pixelsWide] != [bitmapRep2 pixelsWide] || 
		[bitmapRep1 pixelsHigh] != [maskRep pixelsHigh] || [bitmapRep1 pixelsHigh] != [bitmapRep2 pixelsHigh])
		[NSException raise:@"Invalid bitmap(s)" format:@"The bitmaps to compare are not the same size"];
	
	float				matchValue = 0.0;
	int					bytesPerPixel1 = [bitmapRep1 hasAlpha] ? 4 : 3, 
						bytesPerRow1 = [bitmapRep1 bytesPerRow], 
						bytesPerPixel2 = [bitmapRep2 hasAlpha] ? 4 : 3, 
						bytesPerRow2 = [bitmapRep2 bytesPerRow], 
						maskBytesPerPixel = [maskRep hasAlpha] ? 4 : 3, 
						maskBytesPerRow = [maskRep bytesPerRow], 
						xSize = [bitmapRep1 size].width,
						ySize = [bitmapRep1 size].height;
	float				pixelCount = 0.0, // fractional pixels are counted
						pixelsLeft = xSize * ySize;
	NSData				*adjustedMask = [self adjustedMaskForMaskRep:maskRep ofImageRep:bitmapRep1];
	unsigned char		*bitmap1Bytes = [bitmapRep1 bitmapData], 
						*bitmap2Bytes = [bitmapRep2 bitmapData], 
						*maskBytes = [maskRep bitmapData], 
						*adjustedMaskBytes = [adjustedMask bytes];
	
		// Scale the 0.0<->1.0 value back to our internal scale to make calculation faster.
	valueToBeat *= MAX_COLOR_DIFF;
	
		// the size of bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of bitmapRep centered in imageRep will be ignored
	
		// Add up the differences of all the pixels in the two bitmaps weighted by the mask.
	int				x, y;
	for (x = 0; x < xSize; x++)
	{
		for (y = 0; y < ySize; y++)
		{
			unsigned char	*bitmap1_off = bitmap1Bytes + x * bytesPerPixel1 + y * bytesPerRow1,
							*bitmap2_off = bitmap2Bytes + x * bytesPerPixel2 + y * bytesPerRow2;
			pixelColor		color1 = {*bitmap1_off, *(bitmap1_off + 1), *(bitmap1_off + 2)}, 
							color2 = {*bitmap2_off, *(bitmap2_off + 1), *(bitmap2_off + 2)};
			float			adjustedMaskWeight = *(adjustedMaskBytes++) / 255.0;	// 0.0 <-> 1.0
			
			matchValue += (MAX_COLOR_DIFF - colorDifference(color1, color2)) * adjustedMaskWeight;
			pixelCount += (maskRep ? *(maskBytes + x * maskBytesPerPixel + y * maskBytesPerRow) / 255.0 : 1.0);
		}
		pixelsLeft -= ySize;
		
		// Optimization: the lower the matchValue the better so if it's already greater 
		// than the previous best then it's no use going any further.
//		if (matchValue / (float)(pixelCount + pixelsLeft) > valueToBeat)
//			return 1.0;
	}

		// Average the value per active pixel in the original mask and scale into the 0-1 range.
		// A pixel count of zero means that the image was completely transparent and we shouldn't use it.
	matchValue = (pixelCount == 0 ? 1.0 : 1.0 - matchValue / pixelCount / MAX_COLOR_DIFF);
	
	return matchValue;
}


@end
