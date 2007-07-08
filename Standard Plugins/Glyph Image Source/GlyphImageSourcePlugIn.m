//
//  GlyphImageSourcePlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/27/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSourcePlugIn.h"

#import "GlyphImageSource.h"
#import "GlyphImageSourceController.h"


static NSImage	*glyphSourceImage = nil;


@implementation MacOSaiXGlyphImageSourcePlugIn


+ (void)initialize
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	NSString			*imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"GlyphImageSource"];
	glyphSourceImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
	
	// Seed the random number generator
	srandom(time(NULL));
	
	[pool release];
}


+ (NSImage *)image
{
	return glyphSourceImage;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXGlyphImageSource class];
}


+ (Class)editorClass
{
	return [MacOSaiXGlyphImageSourceEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end
