//
//  MacOSaiXBitmapExportSettings.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapExportSettings.h"


@implementation MacOSaiXBitmapExportSettings


- (id)init
{
	if (self = [super init])
	{
		[self setFormat:@"PNG"];
		[self setUnits:inchUnits];
		[self setWidth:0.0];
		[self setHeight:0.0];
		[self setPixelsPerInch:72];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXBitmapExportSettings	*copy = [[MacOSaiXBitmapExportSettings allocWithZone:zone] init];
	
	[copy setFormat:[self format]];
	[copy setWidth:[self width]];
	[copy setHeight:[self height]];
	[copy setUnits:[self units]];
	[copy setPixelsPerInch:[self pixelsPerInch]];
	
	return copy;
}


- (void)setTargetImage:(NSImage *)image
{
		// The width and height will be changed to preserve the existing image area and honor the new aspect ratio.
	float	imageArea = [self width] * [self height], 
			aspectRatio = [image size].width / [image size].height;
	
	if (imageArea == 0.0)
	{
		// Default the image area to the biggest 4x6 that can fit on a printed page with a .5 inch margin, in inches.
		// TODO: use the new image's ratio, not 4x6.
		imageArea = 10.0 * (10.0 / 6.0 * 4.0);
		
		if (bitmapUnits == pixelUnits)
			imageArea *= [self pixelsPerInch] * [self pixelsPerInch];
		else if (bitmapUnits == cmUnits)
			imageArea *= 2.54 * 2.54;
	}
	
	[targetImage release];
	targetImage = [image retain];
	
	float	width = sqrtf(imageArea * aspectRatio), 
			height = width / aspectRatio;
	
	if ([self units] == pixelUnits)
	{
		width = roundf(width);
		height = roundf(height);
	}
	
	[self setWidth:width];
	[self setHeight:height];
}


- (NSImage *)targetImage
{
	return targetImage;
}


- (void)setFormat:(NSString *)format
{
	[bitmapFormat release];
	bitmapFormat = [format copy];
}


- (NSString *)format
{
	return bitmapFormat;
}


- (NSString *)exportFormat
{
	return [self format];
}


- (NSString *)exportExtension
{
	return ([[self format] isEqualToString:@"JPEG 2000"] ? @"jp2" : [[self format] lowercaseString]);
}


- (void)setWidth:(float)width
{
	bitmapWidth = width;
}


- (float)width
{
	return bitmapWidth;
}


- (void)setHeight:(float)height
{
	bitmapHeight = height;
}


- (float)height
{
	return bitmapHeight;
}


- (void)setUnits:(MacOSaiXBitmapUnits)type
{
	bitmapUnits = type;
}


- (MacOSaiXBitmapUnits)units
{
	return bitmapUnits;
}


- (void)setWidthHeightUnits:(NSArray *)array
{
	[self setWidth:[[array objectAtIndex:0] floatValue]];
	[self setHeight:[[array objectAtIndex:1] floatValue]];
	[self setUnits:[[array objectAtIndex:2] intValue]];
}


- (void)setPixelsPerInch:(int)ppi
{
	pixelsPerInch = ppi;
}


- (int)pixelsPerInch
{
	return pixelsPerInch;
}


- (int)pixelWidth
{
	if ([self units] == inchUnits)
		return [self width] * [self pixelsPerInch];
	else if ([self units] == cmUnits)
		return [self width] * 2.54 * [self pixelsPerInch];
	else	// ([self units] == pixelUnits)
		return [self width];
}


- (int)pixelHeight
{
	if ([self units] == inchUnits)
		return [self height] * [self pixelsPerInch];
	else if ([self units] == cmUnits)
		return [self height] * 2.54 * [self pixelsPerInch];
	else // ([self units] == pixelUnits)
		return [self height];
}


- (BOOL)settingsAreValid
{
	return YES;
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[self format], @"Format", 
								[NSNumber numberWithFloat:[self width]], @"Width", 
								[NSNumber numberWithFloat:[self height]], @"Height", 
								[NSNumber numberWithInt:[self units]], @"Units", 
								[NSNumber numberWithInt:[self pixelsPerInch]], @"Resolution", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setFormat:[settings objectForKey:@"Format"]];
	[self setWidth:[[settings objectForKey:@"Width"] floatValue]];
	[self setHeight:[[settings objectForKey:@"Height"] floatValue]];
	[self setUnits:[[settings objectForKey:@"Units"] intValue]];
	[self setPixelsPerInch:[[settings objectForKey:@"Resolution"] intValue]];
	
	return YES;
}


- (id)briefDescription
{
	return nil;
}


- (NSImage *)image
{
	return nil;
}


@end
