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
static NSRecursiveLock  *sQuickTimeLock = nil;


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


+ (NSString *)name
{
	return @"QuickTime Movie";
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


+ (void)lockQuickTime
{
	if (!sQuickTimeLock)
		sQuickTimeLock = [[NSRecursiveLock alloc] init];
	
//	void (*funcPtr)(int) = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.QuickTime")),
//															 CFSTR("EnterMoviesOnThread"));
//	if (funcPtr)
//		funcPtr(1L << 1);
//    EnterMovies();

	[sQuickTimeLock lock];
}


+ (void)unlockQuickTime
{
//	void (*funcPtr)() = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.QuickTime")),
//															 CFSTR("ExitMoviesOnThread"));
//	if (funcPtr)
//		funcPtr();
//    ExitMovies();
    
	[sQuickTimeLock unlock];
}


- (id)init
{
	if (self = [super init])
	{
		currentImageLock = [[NSLock alloc] init];
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
	return [NSString stringWithFormat:@"<MOVIE PATH=\"%@\" LAST_USED_TIME=\"%d\"/>", 
									  [[self path] stringByEscapingXMLEntites], 
									  currentTimeValue];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"MOVIE"])
		[self setPath:[[[settingDict objectForKey:@"PATH"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"LAST_USED_TIME"])
		currentTimeValue = [[[settingDict objectForKey:@"LAST_USED_TIME"] description] intValue];
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
	[movie release];
	movie = nil;

	if (path)
	{
		[[self class] lockQuickTime];
		
		movie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:path] byReference:YES];
		Movie		qtMovie = [movie QTMovie];
		
			// Get the movie's aspect ratio and move its origin to {0, 0}.
		Rect		movieBounds;
		GetMovieBox(qtMovie, &movieBounds);
		aspectRatio = (float)(movieBounds.right - movieBounds.left) / (float)(movieBounds.bottom - movieBounds.top);
		OffsetRect(&movieBounds, -movieBounds.left, -movieBounds.top);
		SetMovieBox(qtMovie, &movieBounds);
		
			// Get the frame rate and duration of the movie.
		minIncrement = GetMovieTimeScale(qtMovie) / 5;   // equals 5 fps
		duration = GetMovieDuration(qtMovie);
		
			// Set the initial image displayed in the sources table to the poster frame.
		NSString	*posterFrameIdentifier = [NSString stringWithFormat:@"%ld", GetMoviePosterTime(qtMovie)];
		[self setCurrentImage:[self imageForIdentifier:posterFrameIdentifier]];
		
		[[self class] unlockQuickTime];
	}
}


- (NSMovie *)movie
{
	return movie;
}


- (float)aspectRatio
{
	return aspectRatio;
}


- (void)setCurrentImage:(NSImage *)image
{
	NSImage	*newImage = [[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)];
	[newImage setCachedSeparately:YES];
	
	NS_DURING
		[newImage lockFocus];
			if ([image size].width > [image size].height)
				[image drawInRect:NSMakeRect(0, (64.0 - 64.0 / [image size].width * [image size].height) / 2.0, 64, 64 / [image size].width * [image size].height)
						 fromRect:NSZeroRect
						operation:NSCompositeCopy
						 fraction:1.0];
			else
				[image drawInRect:NSMakeRect((64.0 - 64.0 / [image size].height * [image size].width) / 2.0, 0, 64.0 / [image size].height * [image size].width, 64)
						 fromRect:NSZeroRect
						operation:NSCompositeCopy
						 fraction:1.0];
			
		// TODO: draw a rough progress indicator at the bottom of the image
			
		[newImage unlockFocus];
	NS_HANDLER
		NSLog(@"QuickTime Image Source: Could not set current image.");
	NS_ENDHANDLER
	
	[currentImageLock lock];
		[currentImage autorelease];
		currentImage = newImage;
	[currentImageLock unlock];
}


	// return the image to be displayed in the list of image sources
- (NSImage *)image;
{
	NSImage	*image = nil;
	
//	[currentImageLock lock];
//		image = (currentImage ? [[currentImage retain] autorelease] : 
//								[[NSWorkspace sharedWorkspace] iconForFile:moviePath]);
//	[currentImageLock unlock];
	
	return image;
}


	// return the text to be displayed in the list of image sources
- (NSString *)descriptor
{
    return moviePath ? [[moviePath lastPathComponent] stringByDeletingPathExtension] : 
					   @"No movie has been specified";
}


- (BOOL)hasMoreImages
{
	return currentTimeValue < duration;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;
{
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionary];
	
	[self nextImageAndIdentifierOnMainThread:parameters];
	
//	[self performSelectorOnMainThread:@selector(nextImageIdentifierOnMainThread:) 
//						   withObject:parameters
//						waitUntilDone:YES];
	
	*identifier = [parameters objectForKey:@"identifier"];
	return [parameters objectForKey:@"image"];
}


- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters
{
	[[self class] lockQuickTime];
	
		// TODO: Rather than using the next interesting time use the image matching code to 
		//       detect when the image changes significantly.
    Movie		qtMovie = [movie QTMovie];
	TimeValue   nextInterestingTime = 0;
	NSString	*identifier = nil;
	NSImage		*image = nil;
	
	do
	{
		GetMovieNextInterestingTime (qtMovie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
		OSErr   err = GetMoviesError();
		
		if (err != noErr)
			NSLog(@"Error %d getting next interesting time.", err);
		else
		{
			if (nextInterestingTime - currentTimeValue < minIncrement)
				currentTimeValue += minIncrement;
			else
				currentTimeValue = nextInterestingTime;
		}
		
		identifier = [NSString stringWithFormat:@"%ld", currentTimeValue];
		image = [self imageForIdentifier:identifier];
	} while (!image && currentTimeValue < duration);
	
	if (image)
	{
//		[self setCurrentImage:image];
		
		[parameters setObject:identifier forKey:@"identifier"];
		[parameters setObject:image forKey:@"image"];
	}

	[[self class] unlockQuickTime];
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*imageAtTimeValue = [[[NSImage alloc] initWithSize:NSMakeSize(64, 64)] autorelease];
	
	[self imageForIdentifierOnMainThread:[NSArray arrayWithObjects:identifier, imageAtTimeValue, nil]];
//	[self performSelectorOnMainThread:@selector(imageForIdentifierOnMainThread:) 
//						   withObject:[NSArray arrayWithObjects:identifier, imageAtTimeValue, nil]
//						waitUntilDone:YES];
	
	return imageAtTimeValue;
}


- (void)imageForIdentifierOnMainThread:(NSArray *)parameters
{
	[[self class] lockQuickTime];

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
			[imageAtTimeValue setCachedSeparately:YES];
			
			[imageAtTimeValue setSize:[imageRep size]];
			
			NS_DURING
				[imageAtTimeValue lockFocus];
					[imageRep drawAtPoint:NSZeroPoint];
				[imageAtTimeValue unlockFocus];
			NS_HANDLER
				NSLog(@"QuickTime Image Source: Could not lock focus on image");
			NS_ENDHANDLER
			
			KillPicture(picHandle);
		}
	}
	
	[[self class] unlockQuickTime];
}


- (void)reset
{
	currentTimeValue = 0;
	
		// Set the initial image displayed in the sources table to the poster frame.
	[[self class] lockQuickTime];
    Movie		qtMovie = [movie QTMovie];
	if (qtMovie)
	{
		NSString	*posterFrameIdentifier = [NSString stringWithFormat:@"%ld", GetMoviePosterTime(qtMovie)];
		[self setCurrentImage:[self imageForIdentifier:posterFrameIdentifier]];
	}
	else
		[self setCurrentImage:nil];	// TBD: return QT icon?  should this even be possible?
	[[self class] unlockQuickTime];
}


- (void)dealloc
{
	[moviePath release];
	[movie release];
	[currentImageLock lock];
		[currentImage release];
		currentImage = nil;
	[currentImageLock unlock];
	[currentImageLock release];
	
	[super dealloc];
}


@end
