//
//  MacOSaiXWebPageExportSettings.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWebPageExportSettings.h"


@implementation MacOSaiXWebPageExportSettings


- (id)init
{
	if (self = [super init])
	{
		[self setWidth:0.0];
		[self setHeight:0.0];
		[self setIncludeTargetImage:NO];
		[self setIncludeTilePopUps:YES];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXWebPageExportSettings	*copy = [[MacOSaiXWebPageExportSettings allocWithZone:zone] init];
	
	[copy setTargetImage:[self targetImage]];
	[copy setWidth:[self width]];	// also sets height
	[copy setIncludeTargetImage:[self includeTargetImage]];
	[copy setIncludeTilePopUps:[self includeTilePopUps]];
	
	return copy;
}


- (void)setTargetImage:(NSImage *)image
{
		// The width and height will be changed to preserve the existing image area and honor the new aspect ratio.
	float	imageArea = [self width] * [self height], 
			aspectRatio = [image size].width / [image size].height;
	
	if (imageArea == 0.0)
	{
			// Default the image area to the target image scaled to 400 pixels wide.
		NSSize	targetImageSize = [image size];
		float	targetImageAspectRatio = targetImageSize.width / targetImageSize.height;
		
		imageArea = 400.0 * (400.0 / targetImageAspectRatio);
	}
	
	[targetImage release];
	targetImage = [image retain];
	
	[self setWidth:sqrtf(imageArea * aspectRatio)];
}


- (NSImage *)targetImage
{
	return targetImage;
}


- (NSString *)exportFormat
{
	return NSLocalizedString(@"web page", @"");
}


- (NSString *)exportExtension
{
	return @"";
}


- (void)setWidth:(int)width
{
	NSSize	targetImageSize = [[self targetImage] size];
	float	aspectRatio = targetImageSize.width / targetImageSize.height;
	
	bitmapWidth = width;
	bitmapHeight = width / aspectRatio;
}


- (int)width
{
	return bitmapWidth;
}


- (void)setHeight:(int)height
{
	NSSize	targetImageSize = [[self targetImage] size];
	float	aspectRatio = targetImageSize.width / targetImageSize.height;
	
	bitmapWidth = height * aspectRatio;
	bitmapHeight = height;
}


- (int)height
{
	return bitmapHeight;
}


- (void)setIncludeTargetImage:(BOOL)flag
{
	includeTargetImage = flag;
}


- (BOOL)includeTargetImage
{
	return includeTargetImage;
}


- (void)setIncludeTilePopUps:(BOOL)flag
{
	includeTilePopUps = flag;
}


- (BOOL)includeTilePopUps
{
	return includeTilePopUps;
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
								[NSNumber numberWithInt:[self width]], @"Width", 
								[NSNumber numberWithInt:[self height]], @"Height", 
								[NSNumber numberWithBool:[self includeTargetImage]], @"Include Target Image", 
								[NSNumber numberWithBool:[self includeTilePopUps]], @"Include Tile Pop Ups", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setWidth:[[settings objectForKey:@"Width"] intValue]];
	[self setHeight:[[settings objectForKey:@"Height"] intValue]];
	[self setIncludeTargetImage:[[settings objectForKey:@"Include Target Image"] boolValue]];
	[self setIncludeTilePopUps:[[settings objectForKey:@"Include Tile Pop Ups"] boolValue]];
	
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
