//
//  MacOSaiXBitmapExportSettings.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


typedef enum { pixelUnits, inchUnits, cmUnits } MacOSaiXBitmapUnits;


@interface MacOSaiXBitmapExportSettings : NSObject <MacOSaiXExportSettings>
{
	NSImage				*targetImage;
	NSString			*bitmapFormat;
	float				bitmapWidth, 
						bitmapHeight;
	MacOSaiXBitmapUnits	bitmapUnits;
	int					pixelsPerInch;
}

- (NSImage *)targetImage;

- (void)setFormat:(NSString *)format;
- (NSString *)format;

- (void)setWidth:(float)width;
- (float)width;

- (void)setHeight:(float)height;
- (float)height;

- (void)setUnits:(MacOSaiXBitmapUnits)units;
- (MacOSaiXBitmapUnits)units;

- (void)setPixelsPerInch:(int)ppi;
- (int)pixelsPerInch;

- (int)pixelWidth;
- (int)pixelHeight;

@end
