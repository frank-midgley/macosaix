//
//  MacOSaiXPDFExportSettings.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPDFExportSettings.h"


@implementation MacOSaiXPDFExportSettings


- (id)init
{
	if (self = [super init])
	{
		[self setUnits:inchUnits];
		[self setWidth:0.0];
		[self setHeight:0.0];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXPDFExportSettings	*copy = [[MacOSaiXPDFExportSettings allocWithZone:zone] init];
	
	[copy setWidth:[self width]];
	[copy setHeight:[self height]];
	[copy setUnits:[self units]];
	
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
		
		if (pageUnits == cmUnits)
			imageArea *= 2.54 * 2.54;
	}
	
	[targetImage release];
	targetImage = [image retain];
	
	float	width = sqrtf(imageArea * aspectRatio), 
			height = width / aspectRatio;
	
	[self setWidth:width];
	[self setHeight:height];
}


- (NSImage *)targetImage
{
	return targetImage;
}


- (NSString *)exportFormat
{
	return NSLocalizedString(@"PDF", @"");
}


- (NSString *)exportExtension
{
	return @"pdf";
}


- (void)setWidth:(float)width
{
	pageWidth = width;
}


- (float)width
{
	return pageWidth;
}


- (void)setHeight:(float)height
{
	pageHeight = height;
}


- (float)height
{
	return pageHeight;
}


- (void)setUnits:(MacOSaiXPDFUnits)type
{
	pageUnits = type;
}


- (MacOSaiXPDFUnits)units
{
	return pageUnits;
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithFloat:[self width]], @"Width", 
								[NSNumber numberWithFloat:[self height]], @"Height", 
								[NSNumber numberWithInt:[self units]], @"Units", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setWidth:[[settings objectForKey:@"Width"] floatValue]];
	[self setHeight:[[settings objectForKey:@"Height"] floatValue]];
	[self setUnits:[[settings objectForKey:@"Units"] intValue]];
	
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
