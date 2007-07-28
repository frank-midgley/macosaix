//
//  MacOSaiXWebPageExportSettings.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXWebPageExportSettings : NSObject <MacOSaiXExportSettings>
{
	NSImage	*targetImage;
	int		bitmapWidth, 
			bitmapHeight;
	BOOL	includeTargetImage, 
			includeTilePopUps;
}

- (NSImage *)targetImage;

- (void)setWidth:(int)width;
- (int)width;

- (void)setHeight:(int)height;
- (int)height;

- (void)setIncludeTargetImage:(BOOL)flag;
- (BOOL)includeTargetImage;

- (void)setIncludeTilePopUps:(BOOL)flag;
- (BOOL)includeTilePopUps;

@end
