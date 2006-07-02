//
//  QuickTimeImageSourceMovie.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/1/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//


@interface QuickTimeImageSourceMovie : NSObject
{
	NSString	*path, 
				*title;
	NSMovie		*movie;
	NSImage		*posterFrame;
	float		aspectRatio;
	long		duration;
}

+ (QuickTimeImageSourceMovie *)movieWithPath:(NSString *)moviePath;

- (id)initWithPath:(NSString *)moviePath;

- (void)setPath:(NSString *)moviePath;
- (NSString *)path;

- (void)setTitle:(NSString *)movieTitle;
- (NSString *)title;

- (void)setPosterFrame:(NSImage *)frame;
- (NSImage *)posterFrame;

- (float)aspectRatio;

- (NSMovie *)movie;

@end
