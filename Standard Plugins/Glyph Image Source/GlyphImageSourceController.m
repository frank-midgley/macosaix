//
//  GlyphImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "GlyphImageSourceController.h"


@implementation GlyphImageSourceController


+ (NSString *)name
{
	return @"Glyphs";
}


- (NSView *)imageSourceView
{
	if (!_imageSourceView)
		[NSBundle loadNibNamed:@"Glyph Image Source" owner:self];
	return _imageSourceView;
}


@end
