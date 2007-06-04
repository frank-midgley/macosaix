//
//  MacOSaiXPDFExportSettings.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


typedef enum { inchUnits, cmUnits } MacOSaiXPDFUnits;


@interface MacOSaiXPDFExportSettings : NSObject <MacOSaiXExportSettings>
{
	NSImage				*targetImage;
	float				pageWidth, 
						pageHeight;
	MacOSaiXPDFUnits	pageUnits;
}

- (NSImage *)targetImage;

- (void)setWidth:(float)width;
- (float)width;

- (void)setHeight:(float)height;
- (float)height;

- (void)setUnits:(MacOSaiXPDFUnits)units;
- (MacOSaiXPDFUnits)units;

@end
