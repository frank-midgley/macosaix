/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "QuickTimeImageSource.h"
#import "QuickTimeImageSourceController.h"
#import "MacOSaiXImageMatcher.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


static NSImage			*sQuickTimeImage = nil;


@interface QuickTimeImageSource (PrivateMethods)
- (void)setCurrentImage:(NSImage *)image;
- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters;
- (void)imageForIdentifierOnMainThread:(NSMutableDictionary *)parameters;
- (NSImage *)frameAtTime:(TimeValue)time thumbnail:(BOOL)getThumbnail;
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


+ (Class)dataSourceEditorClass
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
		movieLock = [[NSRecursiveLock alloc] init];
		
		NSNumber	*saveFramesPref = [[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"]
											objectForKey:@"Save Frames"];
		canRefetchImages = (saveFramesPref ? ![saveFramesPref boolValue] : YES);
		
		constantSamplingRate = 1.0;
		
		recentImageReps = [[NSMutableArray array] retain];
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


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableArray		*archivedImageReps = [NSMutableArray array];
	NSEnumerator		*recentImageRepsEnumerator = [recentImageReps objectEnumerator];
	NSBitmapImageRep	*recentImageRep = nil;
	while (recentImageRep = [recentImageRepsEnumerator nextObject])
		[archivedImageReps addObject:[NSArchiver archivedDataWithRootObject:recentImageRep]];
	
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[self path], @"Path", 
								[NSNumber numberWithLong:currentTimeValue], @"Last Used Time", 
								[NSNumber numberWithBool:!canRefetchImages], @"Save Frames", 
								archivedImageReps, @"Recent Frames", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setPath:[settings objectForKey:@"Path"]];
	currentTimeValue = [[settings objectForKey:@"Last Used Time"] longValue];
	canRefetchImages = ![[settings objectForKey:@"Save Frames"] boolValue];
	
	NSEnumerator	*archivedImageRepsEnumerator = [[settings objectForKey:@"Recent Frames"] objectEnumerator];
	NSData			*archivedImageRep = nil;
	while (archivedImageRep = [archivedImageRepsEnumerator nextObject])
		[recentImageReps addObject:[NSUnarchiver unarchiveObjectWithData:archivedImageRep]];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
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
			GetMovieBox(qtMovie, &nativeBounds);
			aspectRatio = (float)(nativeBounds.right - nativeBounds.left) / (float)(nativeBounds.bottom - nativeBounds.top);
			OffsetRect(&nativeBounds, -nativeBounds.left, -nativeBounds.top);
			if (nativeBounds.right > 80)
				SetRect(&thumbnailBounds, 0, 0, 80, nativeBounds.bottom * 80 / nativeBounds.right);
			else
				thumbnailBounds = nativeBounds;
			
				// Get the frame rate and duration of the movie.
			timeScale = GetMovieTimeScale(qtMovie);
			duration = GetMovieDuration(qtMovie);

			posterFrameTimeValue = GetMoviePosterTime(qtMovie);
			
				// Determine if the movie is thread safe.
			movieIsThreadSafe = YES;
			OSErr	err = DetachMovieFromCurrentThread(qtMovie);
			if (err == componentNotThreadSafeErr)
				movieIsThreadSafe = NO;
			else if (err != noErr)
			{
				#ifdef DEBUG
					NSLog(@"Could not detach from movie (%d)", err);
				#endif
			}
		}
		else
		{
			aspectRatio = 0.0;
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
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[newImage lockFocus];
			[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
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
		[[NSGraphicsContext currentContext] restoreGraphicsState];
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
									  NSLocalizedString(@"No movie has been specified", @"");
}


- (BOOL)hasMoreImages
{
	return currentTimeValue < duration;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;
{
	NSImage	*nextImage = nil;
	*identifier = nil;
	
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionary];
	
	if (movieIsThreadSafe)
	{
		[movieLock lock];
		
		@try
		{
			Movie	qtMovie = [movie QTMovie];
			OSErr	err = AttachMovieToCurrentThread(qtMovie);
			
			if (err == noErr)
			{
				@try
				{
					[self nextImageAndIdentifierOnMainThread:parameters];
				}
				@finally
				{
					DetachMovieFromCurrentThread(qtMovie);
				}
			}
		}
		@finally
		{
			[movieLock unlock];
		}
	}
	else
		[self performSelectorOnMainThread:@selector(nextImageAndIdentifierOnMainThread:) 
							   withObject:parameters
							waitUntilDone:YES];
	
	*identifier = [parameters objectForKey:@"identifier"];
	nextImage = [parameters objectForKey:@"image"];
	
	if (nextImage)
		[self setCurrentImage:nextImage];
	
	return nextImage;
}


- (BOOL)imageIsSignificantlyDifferent:(NSImage *)image
{
	BOOL				isDifferent = YES;
	
		// Get a thumbnail bitmap.
	NSImage				*thumbnail = [image copyWithLargestDimension:16];
	NSBitmapImageRep	*imageRep = [[thumbnail representations] lastObject];
	
		// See if it is similar to any of the recent bitmaps.
	MacOSaiXImageMatcher	*imageMatcher = [NSClassFromString(@"MacOSaiXImageMatcher") sharedMatcher];
	NSEnumerator			*recentImageRepsEnumerator = [recentImageReps objectEnumerator];
	NSBitmapImageRep		*recentImageRep = nil;
	while (recentImageRep = [recentImageRepsEnumerator nextObject])
		if ([imageMatcher compareImageRep:imageRep 
								 withMask:nil 
							   toImageRep:recentImageRep 
							 previousBest:1.0] < 0.02)
		{
			isDifferent = NO;
			break;
		}
	
	if (isDifferent)
	{
		[recentImageReps insertObject:imageRep atIndex:0];
		if ([recentImageReps count] > 32)
			[recentImageReps removeLastObject];
	}
	
	[thumbnail release];
	
	return isDifferent;
}


- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters
{
	if ([self samplingRateType] == 0)
	{
		do
		{
			currentTimeValue += timeScale / 10;	// max 10 fps
			
			NSImage	*image = [self frameAtTime:currentTimeValue thumbnail:YES];
			
			if (image && [self imageIsSignificantlyDifferent:image])
			{
				[parameters setObject:[NSString stringWithFormat:@"%ld", currentTimeValue] forKey:@"identifier"];
				[parameters setObject:image forKey:@"image"];
			}
		} while (currentTimeValue < duration && ![parameters objectForKey:@"image"]);
	}
	else
	{
		currentTimeValue += [self constantSamplingRate] * timeScale;
		
		if (currentTimeValue < duration)
		{
			NSImage	*image = [self frameAtTime:currentTimeValue thumbnail:YES];
			
			if (image)
			{
				[parameters setObject:[NSString stringWithFormat:@"%ld", currentTimeValue] forKey:@"identifier"];
				[parameters setObject:image forKey:@"image"];
			}
		}
	}
}


- (void)setSamplingRateType:(int)type
{
	samplingRateType = type;
}


- (int)samplingRateType
{
	return samplingRateType;
}


- (void)setConstantSamplingRate:(float)rate
{
	constantSamplingRate = rate;
}


- (float)constantSamplingRate
{
	return constantSamplingRate;
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


- (NSImage *)frameAtTime:(TimeValue)time thumbnail:(BOOL)getThumbnail
{
	NSImage	*image = nil;
	
	if (time <= duration)
	{
		Movie	qtMovie = [movie QTMovie];
		
		if (getThumbnail)
			SetMovieBox(qtMovie, &nativeBounds);
		else
			SetMovieBox(qtMovie, &thumbnailBounds);
			
		PicHandle	picHandle = GetMoviePict(qtMovie, time);
		OSErr       err = GetMoviesError();
		if (err != noErr)
		{
			#ifdef DEBUG
				NSLog(@"Error %d getting movie picture.", err);
			#endif
		}
		else if (picHandle)
		{
			NSData			*imageData = [NSData dataWithBytes:*picHandle length:GetHandleSize((Handle)picHandle)];
			NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:imageData];
			image = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease];
			@try
			{
				[image lockFocus];
				[imageRep drawAtPoint:NSMakePoint(0.0, 0.0)];
				[image unlockFocus];
			}
			@catch (NSException *)
			{
				image = nil;
			}
			
			KillPicture(picHandle);
		}
	}
	
	return image;
}


- (void)imageForIdentifierOnMainThread:(NSMutableDictionary *)parameters
{
	NSImage	*image = [self frameAtTime:[[parameters objectForKey:@"Identifier"] intValue] 
							 thumbnail:[[parameters objectForKey:@"Thumbnail"] boolValue]];
	
	if (image)
		[parameters setObject:image forKey:@"Image"];
}


- (NSImage *)imageForIdentifier:(NSString *)identifier thumbnail:(BOOL)getThumbnail
{
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											identifier, @"Identifier",
											[NSNumber numberWithBool:getThumbnail], @"Thumbnail", 
											nil];
	
	if (movieIsThreadSafe)
	{
		[movieLock lock];
		
		@try
		{
			Movie	qtMovie = [movie QTMovie];
			OSErr	err = AttachMovieToCurrentThread(qtMovie);
			
			if (err == noErr)
			{
				[self imageForIdentifierOnMainThread:parameters];
				
				DetachMovieFromCurrentThread(qtMovie);
			}
		}
		@finally
		{
			[movieLock unlock];
		}
	}
	else
		[self performSelectorOnMainThread:@selector(imageForIdentifierOnMainThread:) 
							   withObject:parameters
							waitUntilDone:YES];
	
	return [parameters objectForKey:@"Image"];
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return [NSString stringWithFormat:@"%@:%@", [self path], identifier];
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	return [self imageForIdentifier:identifier thumbnail:YES];
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	return [self imageForIdentifier:identifier thumbnail:NO];
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
	[recentImageReps removeAllObjects];
	
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
	[recentImageReps release];
	
	[super dealloc];
}


@end
