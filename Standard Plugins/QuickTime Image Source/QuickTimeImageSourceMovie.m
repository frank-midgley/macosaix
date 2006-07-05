//
//  QuickTimeImageSourceMovie.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/1/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "QuickTimeImageSourceMovie.h"
#import "QuickTimeImageSource.h"
#import "NSString+MacOSaiX.h"
#import <QuickTime/QuickTime.h>


@implementation QuickTimeImageSourceMovie


+ (void)initialize
{
	if ([self class] == [QuickTimeImageSourceMovie class])
	{
		[self setKeys:[NSArray arrayWithObject:@"aspectRation"] triggerChangeNotificationsForDependentKey:@"aspectRatioString"];
		[self setKeys:[NSArray arrayWithObject:@"duration"] triggerChangeNotificationsForDependentKey:@"durationString"];
	}
}


+ (QuickTimeImageSourceMovie *)movieWithPath:(NSString *)moviePath
{
	return [[[[self class] alloc] initWithPath:moviePath] autorelease];
}


- (id)initWithPath:(NSString *)moviePath
{
	if (self = [super init])
	{
		[self setPath:moviePath];
		[self setTitle:[[moviePath lastPathComponent] stringByDeletingPathExtension]];
	}
	
	return self;
}


- (void)setPath:(NSString *)moviePath
{
	[path release];
	path = [moviePath copy];
}


- (NSString *)path
{
	return path;
}


- (void)setTitle:(NSString *)movieTitle
{
	[title release];
	title = [movieTitle retain];
}


- (NSString *)title
{
	return title;
}


- (void)setPosterFrame:(NSImage *)frame
{
	[posterFrame release];
	posterFrame = [frame retain];
}


- (NSImage *)posterFrame
{
	return (posterFrame ? posterFrame : [QuickTimeImageSource image]);
}


- (float)aspectRatio
{
	return aspectRatio;
}


- (NSString *)aspectRatioString
{
	return [NSString stringWithAspectRatio:aspectRatio];
}


- (NSString *)durationString
{
	return [NSString stringWithFormat:@"%02d:%02d:%02d", duration / 60 / 60, (duration / 60) % 60, duration % 60];
}


- (NSMovie *)movie
{
	if (!movie && path)
	{
		movie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
	
		if (movie)
		{
			Movie		qtMovie = [movie QTMovie];
			
				// Get the movie's aspect ratio.
			Rect		movieBounds;
			GetMovieBox(qtMovie, &movieBounds);
			[self setValue:[NSNumber numberWithFloat:(float)(movieBounds.right - movieBounds.left) / 
												     (float)(movieBounds.bottom - movieBounds.top)]
					forKey:@"aspectRatio"];
			
				// Get the length of the movie in seconds.
			[self setValue:[NSNumber numberWithInt:GetMovieDuration(qtMovie) / GetMovieTimeScale(qtMovie)]
					forKey:@"duration"];
			
				// Get the poster frame or the generic QuickTime icon if the poster is not available.
			PicHandle	picHandle = GetMoviePosterPict(qtMovie);
			OSErr       err = GetMoviesError();
			if (err == noErr && picHandle)
			{
				NSData	*imageData = [NSData dataWithBytes:*picHandle length:GetHandleSize((Handle)picHandle)];
				[self setValue:[[[NSImage alloc] initWithData:imageData] autorelease] forKey:@"posterFrame"];
				KillPicture(picHandle);
			}
		}
	}
	
	return movie;
}


- (void)dealloc
{
	[path release];
	[title release];
	[posterFrame release];
	[movie release];
	
	[super dealloc];
}

@end
