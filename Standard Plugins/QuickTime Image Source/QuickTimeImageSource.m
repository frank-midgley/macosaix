/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "QuickTimeImageSource.h"
#import "QuickTimeImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


static NSImage			*sQuickTimeImage = nil;


@interface QuickTimeImageSource (PrivateMethods)
- (void)setCurrentImage:(NSImage *)image;
- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters;
- (void)imageForIdentifierOnMainThread:(NSArray *)parameters;
@end


@implementation QuickTimeImageSource


+ (void)initialize
{
	NSURL		*quicktimeAppURL = nil;
	LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.quicktimeplayer"), NULL, NULL, (CFURLRef *)&quicktimeAppURL);
	
	sQuickTimeImage = [[[NSWorkspace sharedWorkspace] iconForFile:[quicktimeAppURL path]] retain];
}


+ (NSImage *)image
{
	return sQuickTimeImage;
}


+ (Class)editorClass
{
	return [QuickTimeImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		movieLock = [[NSLock alloc] init];
		
		NSNumber	*saveFramesPref = [[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"]
											objectForKey:@"Save Frames"];
		canRefetchImages = (saveFramesPref ? ![saveFramesPref boolValue] : YES);
	}

    return self;
}


- (id)initWithPath:(NSString *)path
{
	if (self = [self init])
	{
		[self setPath:path];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<MOVIE PATH=\"%@\" LAST_USED_TIME=\"%d\" SAVE_FRAMES=\"%@\"/>", 
									  [[self path] stringByEscapingXMLEntites], 
									  currentTimeValue,
									  (canRefetchImages ? @"NO" : @"YES")];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"MOVIE"])
	{
		currentTimeValue = [[[settingDict objectForKey:@"LAST_USED_TIME"] description] intValue];
		[self setPath:[[[settingDict objectForKey:@"PATH"] description] stringByUnescapingXMLEntites]];
		
		NSString	*saveFrames = [[settingDict objectForKey:@"SAVE_FRAMES"] description];
		if ([saveFrames isEqualToString:@"YES"])
			[self setCanRefetchImages:NO];
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
//	[self updateQueryAndDescriptor];
}


- (id)copyWithZone:(NSZone *)zone
{
	QuickTimeImageSource	*copy = [[QuickTimeImageSource allocWithZone:zone] initWithPath:[self path]];
	
	return copy;
}


- (NSString *)path
{
	return moviePath;
}


- (void)setPath:(NSString *)path
{
	[moviePath release];
	moviePath = [path copy];
	
	if (movie)
	{
		if (movieIsThreadSafe)
			AttachMovieToCurrentThread([movie QTMovie]);
		[movie release];
		movie = nil;
	}
	
	if (path)
	{
		TimeValue	posterFrameTimeValue = 0;
		
		movie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
		
		if (movie)
		{
			Movie		qtMovie = [movie QTMovie];
			
				// Get the movie's aspect ratio and move its origin to {0, 0}.
			Rect		movieBounds;
			GetMovieBox(qtMovie, &movieBounds);
			aspectRatio = (float)(movieBounds.right - movieBounds.left) / (float)(movieBounds.bottom - movieBounds.top);
			OffsetRect(&movieBounds, -movieBounds.left, -movieBounds.top);
			SetMovieBox(qtMovie, &movieBounds);
			
				// Get the frame rate and duration of the movie.
			timeScale = GetMovieTimeScale(qtMovie);
			duration = GetMovieDuration(qtMovie);
				
				// The smallest step to take even if GetNextInterestingTime() returns a smaller value.
			minIncrement = timeScale / 5;   // equals 5 fps

			posterFrameTimeValue = GetMoviePosterTime(qtMovie);
			
				// Determine if the movie is thread safe.
			movieIsThreadSafe = YES;
			OSErr	err = DetachMovieFromCurrentThread(qtMovie);
			if (err == componentNotThreadSafeErr)
				movieIsThreadSafe = NO;
			else if (err != noErr)
				NSLog(@"Could not detach from movie (%d)", err);
		}
		else
		{
			aspectRatio = 1.0;
			timeScale = 15;
			duration = 0;
		}
		
			// Set the initial image displayed in the sources table to the poster frame.
		NSString	*identifier = [NSString stringWithFormat:@"%ld", (currentTimeValue > 0 && currentTimeValue < duration ? currentTimeValue : posterFrameTimeValue)];
		[self setCurrentImage:[self imageForIdentifier:identifier]];
	}
}


- (float)aspectRatio
{
	return aspectRatio;
}


- (void)setCurrentImage:(NSImage *)image
{
	NSImage	*newImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
	int		bottomEdge = 0.0;
	
	@try
	{
		[newImage lockFocus];
			if ([image size].width > [image size].height)
			{
				float	scaledHeight = 32.0 / [image size].width * [image size].height;
				[image drawInRect:NSMakeRect(0, (32.0 - scaledHeight) / 2.0, 32.0, scaledHeight)
						 fromRect:NSZeroRect
						operation:NSCompositeCopy
						 fraction:1.0];
				
				bottomEdge = MAX(0.0, (32.0 - scaledHeight) / 2.0 - 4.0);
			}
			else
				[image drawInRect:NSMakeRect((32.0 - 32.0 / [image size].height * [image size].width) / 2.0, 0, 32.0 / [image size].height * [image size].width, 64)
						 fromRect:NSZeroRect
						operation:NSCompositeCopy
						 fraction:1.0];
			
			// Draw a progress indicator at the bottom of the image.
		NSRect	progressRect = NSMakeRect(0.0, bottomEdge, 32.0, 4.0);
		[[NSColor lightGrayColor] set];
		NSRectFill(progressRect);
		float	progress = 31.0 * currentTimeValue / duration;
		[[NSColor blueColor] set];
		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(progress - 1.0, bottomEdge + 0.5, 3.0, 3.0)] fill]; 
		[[NSColor grayColor] set];
		NSFrameRect(progressRect);
	}
	@catch (NSException *exception)
	{
		#ifdef DEBUG
			NSLog(@"QuickTime Image Source: Could not set current image.");
		#endif
	}
	@finally
	{
		[newImage unlockFocus];
	}
	
	[currentImage autorelease];
	currentImage = newImage;
}


	// return the image to be displayed in the list of image sources
- (NSImage *)image;
{
	NSImage	*image = [[currentImage retain] autorelease];
	
	if (!image)
		image = [[NSWorkspace sharedWorkspace] iconForFile:moviePath];
	
	return image;
}


	// return the text to be displayed in the list of image sources
- (id)descriptor
{
    return ([moviePath length] > 0) ? [[moviePath lastPathComponent] stringByDeletingPathExtension] : 
									  @"No movie has been specified";
}


- (BOOL)hasMoreImages
{
	return currentTimeValue < duration;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;
{
	NSImage	*nextImage = nil;
	*identifier = nil;
	
	if (movieIsThreadSafe)
	{
		[movieLock lock];
		
		@try
		{
			Movie	qtMovie = [movie QTMovie];
			OSErr	err = AttachMovieToCurrentThread(qtMovie);
			
			if (err == noErr)
			{
					// TODO: Rather than using the next interesting time use the image matching code to 
					//       detect when the image changes significantly.
				TimeValue   nextInterestingTime = 0;
				GetMovieNextInterestingTime (qtMovie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
				
				if (nextInterestingTime - currentTimeValue < minIncrement)
					currentTimeValue += minIncrement;
				else
					currentTimeValue = nextInterestingTime;
				
				if (currentTimeValue < duration)
					*identifier = [NSString stringWithFormat:@"%ld", currentTimeValue];
				
				DetachMovieFromCurrentThread(qtMovie);
			}
		}
		@finally
		{
			[movieLock unlock];
		}
		
		if (*identifier)
			nextImage = [self imageForIdentifier:*identifier];
		if (!nextImage)
			*identifier = nil;
	}
	else
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionary];
		
		[self performSelectorOnMainThread:@selector(nextImageAndIdentifierOnMainThread:) 
							   withObject:parameters
							waitUntilDone:YES];
		
		*identifier = [parameters objectForKey:@"identifier"];
		nextImage = [parameters objectForKey:@"image"];
	}
	
	if (nextImage)
		[self setCurrentImage:nextImage];
	
	return nextImage;
}


- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters
{
	// TODO: Rather than using the next interesting time use the image matching code to 
	//       detect when the image changes significantly.
	
    Movie		qtMovie = [movie QTMovie];
	TimeValue   nextInterestingTime = 0;
	NSString	*identifier = nil;
	NSImage		*image = [[[NSImage alloc] initWithSize:NSMakeSize(64, 64)] autorelease];
	[image removeRepresentation:[[image representations] lastObject]];
	
	GetMovieNextInterestingTime (qtMovie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
	if (nextInterestingTime - currentTimeValue < minIncrement)
		currentTimeValue += minIncrement;
	else
		currentTimeValue = nextInterestingTime;
	
	if (currentTimeValue < duration)
	{
		identifier = [NSString stringWithFormat:@"%ld", currentTimeValue];
		
		[self imageForIdentifierOnMainThread:[NSArray arrayWithObjects:identifier, image, nil]];
		
		if ([[image representations] count] > 0)
		{
			[parameters setObject:identifier forKey:@"identifier"];
			[parameters setObject:image forKey:@"image"];
		}
	}
}


- (void)setCanRefetchImages:(BOOL)flag
{
	if (canRefetchImages != flag)
	{
		canRefetchImages = flag;
	}
}


- (BOOL)canRefetchImages
{
	return canRefetchImages;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage	*imageAtTimeValue = nil;
	
	if (movieIsThreadSafe)
	{
		[movieLock lock];
		
		@try
		{
			Movie	qtMovie = [movie QTMovie];
			OSErr	err = AttachMovieToCurrentThread(qtMovie);
			
			if (err == noErr)
			{
				TimeValue	requestedTime = [identifier intValue];
				
				if (requestedTime <= duration)
				{
					PicHandle	picHandle = GetMoviePict(qtMovie, requestedTime);
					OSErr       err = GetMoviesError();
					if (err != noErr)
						NSLog(@"Error %d getting movie picture.", err);
					else if (picHandle)
					{
						NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:[NSData dataWithBytes:*picHandle 
																									length:GetHandleSize((Handle)picHandle)]];
						imageAtTimeValue = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease];
						@try
						{
							[imageAtTimeValue lockFocus];
								[imageRep drawAtPoint:NSMakePoint(0.0, 0.0)];
							[imageAtTimeValue unlockFocus];
						}
						@finally {}
						
						KillPicture(picHandle);
					}
				}
				
				DetachMovieFromCurrentThread(qtMovie);
			}
		}
		@finally
		{
			[movieLock unlock];
		}
	}
	else
	{
		imageAtTimeValue = [[[NSImage alloc] initWithSize:NSMakeSize(64, 64)] autorelease];
		
		[self performSelectorOnMainThread:@selector(imageForIdentifierOnMainThread:) 
							   withObject:[NSArray arrayWithObjects:identifier, imageAtTimeValue, nil]
							waitUntilDone:YES];
	}
	
	return imageAtTimeValue;
}


- (void)imageForIdentifierOnMainThread:(NSArray *)parameters
{
    Movie		qtMovie = [movie QTMovie];
	TimeValue	requestedTime = [[parameters objectAtIndex:0] intValue];
	
	if (requestedTime <= duration)
	{
		PicHandle	picHandle = GetMoviePict(qtMovie, requestedTime);
		OSErr       err = GetMoviesError();
		if (err != noErr)
			NSLog(@"Error %d getting movie picture.", err);
		else if (picHandle)
		{
			NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:[NSData dataWithBytes:*picHandle 
																						length:GetHandleSize((Handle)picHandle)]];
			NSImage			*imageAtTimeValue = [parameters objectAtIndex:1];
			[imageAtTimeValue setSize:[imageRep size]];
			@try
			{
				[imageAtTimeValue lockFocus];
				[imageRep drawAtPoint:NSMakePoint(0.0, 0.0)];
				[imageAtTimeValue unlockFocus];
			}
			@finally {}
			
			KillPicture(picHandle);
		}
	}
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	NSString	*title = [[moviePath lastPathComponent] stringByDeletingPathExtension];
	float		timeIndex = (float)[identifier intValue] / (float)timeScale;
	int			wholeSeconds = timeIndex,
				hours = wholeSeconds / 3600, 
				minutes = (wholeSeconds - hours * 60) / 60, 
				seconds = wholeSeconds % 60, 
				milliseconds = (timeIndex - wholeSeconds) * 1000;
	
	return [NSString stringWithFormat:@"%@ [%d:%02d:%02d.%03d]", title, hours, minutes, seconds, milliseconds];
}	


- (void)reset
{
	if (!movie)
		return;
	
	currentTimeValue = 0;
	
	if (movieIsThreadSafe)
	{
			// Set the initial image displayed in the sources table to the poster frame.
		[movieLock lock];
		
		@try
		{
			Movie		qtMovie = [movie QTMovie];
			OSErr	err = AttachMovieToCurrentThread(qtMovie);
			
			if (err == noErr)
			{
				if (qtMovie)
				{
					NSString	*posterFrameIdentifier = [NSString stringWithFormat:@"%ld", GetMoviePosterTime(qtMovie)];
					[self setCurrentImage:[self imageForIdentifier:posterFrameIdentifier]];
				}
				else
					[self setCurrentImage:nil];
				
				DetachMovieFromCurrentThread(qtMovie);
			}
		}
		@finally
		{
			[movieLock unlock];
		}
	}
	else if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:NO];
	else
	{
			// Set the initial image displayed in the sources table to the poster frame.
		Movie		qtMovie = [movie QTMovie];
		if (qtMovie)
		{
			NSString	*posterFrameIdentifier = [NSString stringWithFormat:@"%ld", GetMoviePosterTime(qtMovie)];
			[self setCurrentImage:[self imageForIdentifier:posterFrameIdentifier]];
		}
		else
			[self setCurrentImage:nil];
	}
}


- (void)dealloc
{
	[self setPath:nil];
	[movieLock release];
	[currentImage release];
	
	[super dealloc];
}


@end
