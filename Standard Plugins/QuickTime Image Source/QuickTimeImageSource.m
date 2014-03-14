/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "QuickTimeImageSource.h"
#import "QuickTimeImageSourceController.h"
#import "NSString+MacOSaiX.h"

#include <Accelerate/Accelerate.h>
#import <malloc/malloc.h>
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
	OSStatus	status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.QuicktimePlayerX"), NULL, NULL, (CFURLRef *)&quicktimeAppURL);
	
    if (status != noErr)
        status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.quicktimeplayer"), NULL, NULL, (CFURLRef *)&quicktimeAppURL);
    
	if (status == noErr && quicktimeAppURL)
	{
		sQuickTimeImage = [[[NSWorkspace sharedWorkspace] iconForFile:[quicktimeAppURL path]] retain];
		
		CFRelease(quicktimeAppURL);
	}
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
	if ((self = [super init]))
	{
		movieLock = [[NSRecursiveLock alloc] init];
		
		NSNumber	*saveFramesPref = [[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"]
											objectForKey:@"Save Frames"];
		canRefetchImages = (saveFramesPref ? ![saveFramesPref boolValue] : YES);
	}

    return self;
}


- (id)initWithPath:(NSString *)path
{
	if ((self = [self init]))
	{
		[self setPath:path];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<MOVIE PATH=\"%@\" LAST_USED_TIME=\"%ld\" SAVE_FRAMES=\"%@\"/>", 
									  [[self path] stringByEscapingXMLEntites], 
									  currentTime.timeValue,
									  (canRefetchImages ? @"NO" : @"YES")];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"MOVIE"])
	{
		currentTime.timeValue = [[[settingDict objectForKey:@"LAST_USED_TIME"] description] intValue];
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
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:path waitUntilDone:YES];
	else
	{
			// Get rid of the current movie.
		if (movie)
		{
//			SetMovieVisualContext([movie quickTimeMovie], NULL);
			[movie release];
			movie = nil;
		}
		
		[moviePath release];
		moviePath = [path copy];
		
		if (path)
		{
			QTTime		posterFrameTime = {0, 0, 0};
			NSError		*movieError = nil;
			
			movie = [[QTMovie alloc] initWithURL:[NSURL fileURLWithPath:path] error:&movieError];
			
			if (movie)
			{
//				Movie		qtMovie = [movie quickTimeMovie];
				
					// Get the movie's aspect ratio and move its origin to {0, 0}.
//				Rect		movieBounds;
//				GetMovieBox(qtMovie, &movieBounds);
//				aspectRatio = (float)(movieBounds.right - movieBounds.left) / (float)(movieBounds.bottom - movieBounds.top);
//				movieBounds.right -= movieBounds.left;
//				movieBounds.top -= movieBounds.bottom;
//				movieBounds.top = movieBounds.left = 0;
//				SetMovieBox(qtMovie, &movieBounds);
				NSSize		movieSize = [[movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
				aspectRatio = movieSize.width / movieSize.height;
				
					// Get the frame rate and duration of the movie.
//				timeScale = GetMovieTimeScale(qtMovie);
//				duration = GetMovieDuration(qtMovie);
				duration = [movie duration];
				
					// The smallest step to take even if GetNextInterestingTime() returns a smaller value.
				minIncrement = (QTTime){5, 60, 0};	//duration.timeScale / 5;	// equals 5 fps

				//posterFrameTimeValue = GetMoviePosterTime(qtMovie);
				posterFrameTime = [[movie attributeForKey:QTMoviePosterTimeAttribute] QTTimeValue];
				
//				if ([NSBitmapImageRep instancesRespondToSelector:@selector(initWithBitmapDataPlanes:pixelsWide:pixelsHigh:bitsPerSample:samplesPerPixel:hasAlpha:isPlanar:colorSpaceName:bitmapFormat:bytesPerRow:bitsPerPixel:)])
//				{
//					// Have the movie render to a bitmap visual context.
//					
//					NSDictionary		*bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
//																	[NSNumber numberWithInt:k32ARGBPixelFormat], kCVPixelBufferPixelFormatTypeKey, 
//																	[NSNumber numberWithInt:movieBounds.right], kCVPixelBufferWidthKey, 
//																	[NSNumber numberWithInt:movieBounds.bottom], kCVPixelBufferHeightKey, 
//																	[NSNumber numberWithInt:16], kCVPixelBufferBytesPerRowAlignmentKey, 
//																	nil], 
//										*contextAttributes = [NSDictionary dictionaryWithObject:bufferAttributes forKey:(NSString *)kQTVisualContextPixelBufferAttributesKey];
//					QTVisualContextRef	qtContext = NULL;
//					OSStatus			contextCreateStatus = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)contextAttributes, &qtContext);
//					
//					if (contextCreateStatus != noErr)
//					{
//						#ifdef DEBUG
//							NSLog(@"hmm");
//						#endif
//					}
//					else
//					{
//						OSStatus	setContextStatus = SetMovieVisualContext(qtMovie, qtContext);
//						
//						if (setContextStatus != noErr)
//						{
//							#ifdef DEBUG
//								NSLog(@"hmm");
//							#endif
//						}
//						
//						QTVisualContextRelease(qtContext);
//					}
//					
//					SetMovieActive(qtMovie, TRUE);
//				}
			}
			else
			{
				aspectRatio = 1.0;
				duration = QTZeroTime;
			}
			
				// Set the initial image displayed in the sources table to the poster frame.
			NSString	*identifier = [NSString stringWithFormat:@"%ld", (QTTimeCompare(QTZeroTime, currentTime) == NSOrderedAscending && QTTimeCompare(currentTime, duration) == NSOrderedAscending ? currentTime.timeValue : posterFrameTime.timeValue)];
			[self setCurrentImage:[self imageForIdentifier:identifier]];
		}
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
		float	progress = (currentTime.timeScale == 0 ? 0 : 31.0 * (currentTime.timeValue / currentTime.timeScale) / (duration.timeValue / duration.timeScale));
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
	return QTTimeCompare(currentTime, duration) == NSOrderedAscending;
}


- (NSImage *)imageAtTime:(QTTime)time
{
	NSImage	*image = nil;
#ifdef DEBUG
	static UInt32	grabTime = 0, grabCount = 0;
	UInt32			startTime = TickCount();
#endif
	
	image = [movie frameImageAtTime:time];
	
//	if (time <= duration)
//	{
//		
//			// Grab the image using a visual context if this system is running QT7 & 10.4.
//		if (QTPixelBufferContextCreate && [NSBitmapImageRep instancesRespondToSelector:@selector(initWithBitmapDataPlanes:pixelsWide:pixelsHigh:bitsPerSample:samplesPerPixel:hasAlpha:isPlanar:colorSpaceName:bitmapFormat:bytesPerRow:bitsPerPixel:)])
//		{
//				// Move the movie to the desired frame.
//			SetMovieTimeValue([movie quickTimeMovie], time);
//			OSErr				setMovieTimeErr = GetMoviesError();
//			if (setMovieTimeErr != noErr)
//			{
//				#ifdef DEBUG
//					NSLog(@"hmm");
//				#endif
//			}
//			else
//			{
//					// Let QT render the frame.
//				MoviesTask([movie quickTimeMovie], 0);
//				OSErr				moviesTaskErr = GetMoviesError();
//				if (moviesTaskErr != noErr)
//				{
//					#ifdef DEBUG
//						NSLog(@"hmm");
//					#endif
//				}
//				else
//				{
//						// Grab the pixel buffer for the current frame.
//					QTVisualContextRef	qtContext = NULL;
//					OSStatus			getContextStatus = GetMovieVisualContext([movie quickTimeMovie], &qtContext);
//					
//					if (getContextStatus != noErr || !qtContext)
//					{
//						#ifdef DEBUG
//							NSLog(@"hmm");
//						#endif
//					}
//					else
//					{
//						CVImageBufferRef	cvBuffer = NULL;
//						OSStatus			copyImageStatus = QTVisualContextCopyImageForTime(qtContext, kCFAllocatorDefault, NULL, &cvBuffer);
//						if (copyImageStatus != noErr)
//						{
//							#ifdef DEBUG
//								NSLog(@"hmm");
//							#endif
//						}
//						else
//						{
//								// Create an image rep from the pixel buffer.
//							CVReturn	lockAddressResult = CVPixelBufferLockBaseAddress(cvBuffer, 0);
//							if (lockAddressResult != kCVReturnSuccess)
//							{
//								#ifdef DEBUG
//									NSLog(@"hmm");
//								#endif
//							}
//							else
//							{
//								void				*baseAddress = CVPixelBufferGetBaseAddress(cvBuffer);
//								size_t				bufferSize = CVPixelBufferGetDataSize(cvBuffer);
//								NSBitmapImageRep	*imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil	
//																										 pixelsWide:CVPixelBufferGetWidth(cvBuffer) 
//																										 pixelsHigh:CVPixelBufferGetHeight(cvBuffer) 
//																									  bitsPerSample:8 
//																									samplesPerPixel:4 
//																										   hasAlpha:YES 
//																										   isPlanar:NO 
//																									 colorSpaceName:NSDeviceRGBColorSpace 
//																									   bitmapFormat:NSAlphaFirstBitmapFormat 
//		//																								bytesPerRow:CVPixelBufferGetBytesPerRow(cvBuffer) 
//																									   bitsPerPixel:0] autorelease];
//								
//								if (!imageRep)
//								{
//									#ifdef DEBUG
//										NSLog(@"hmm");
//									#endif
//								}
//								else
//								{
//									memcpy([imageRep bitmapData], baseAddress, bufferSize);
//									
//										// Wrap the image rep in an image.
//									image = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease];
//									[image addRepresentation:imageRep];
//								}
//								
//								CVReturn	unlockAddressResult = CVPixelBufferUnlockBaseAddress(cvBuffer, 0);
//								if (unlockAddressResult != kCVReturnSuccess)
//								{
//									#ifdef DEBUG
//										NSLog(@"hmm");
//									#endif
//								}
//							}
//							
//							CVBufferRelease(cvBuffer);
//						}
//						
//						QTVisualContextTask(qtContext);
//					}
//				}
//			}
//		}
//		
//			// Use GetMoviePict() if this system doesn't have QT7/10.4 or if the QT7/10.4 code failed.
//		if (!image)
//		{
//			PicHandle	picHandle = GetMoviePict([movie quickTimeMovie], time);
//			OSErr       err = GetMoviesError();
//			if (err != noErr)
//			{
//				#ifdef DEBUG
//					NSLog(@"Error %d getting frame from %@.", err, [self path]);
//				#endif
//			}
//			else if (picHandle)
//			{
//				// Create an NSImage from the PICT.
//				
//				NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:[NSData dataWithBytes:*picHandle length:GetHandleSize((Handle)picHandle)]];
//				
//				if (imageRep && [imageRep size].width >= 1.0 && [imageRep size].height >= 1.0)
//				{
//					image = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease];
//					
//						// Render the PICT rep into the image so that any QT callbacks happen here and not on some other thread that isn't set up for them.
//					@try
//					{
//						[image lockFocus];
//						[imageRep drawAtPoint:NSZeroPoint];
//						[image unlockFocus];
//					}
//					@catch (NSException *exception)
//					{
//						#ifdef DEBUG
//							NSLog(@"Exception raised getting frame from movie: %@", [exception reason]);
//						#endif
//					}
//					@finally {}
//				}
//				
//				KillPicture(picHandle);
//			}
//		}
		
		#ifdef DEBUG
			grabTime += TickCount() - startTime;
			grabCount++;
			NSLog(@"Average grab time: %f sec", grabTime / 60.0 / grabCount);
		#endif
//	}
	
	return image;
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	// TODO: pull the image from a movie in a persistent offscreen GWorld to avoid calling GetMoviePict().  Should be much faster but may have threading issues.
	NSError	*error = nil;
	NSImage	*nextImage = nil;
	BOOL	onMainThread = pthread_main_np(), 
			callToMainThread = NO, 
			attachedToCurrentThread = NO;	// Will always be NO for the main thread.
//	Movie	qtMovie = [movie quickTimeMovie];
	
	*image = nil;
	*identifier = nil;
	
	[movieLock lock];
	
		// Try to attach the movie to this thread if necessary.  Call over to the main thread if that doesn't work.
//	OSErr	err = GetMovieThreadAttachState(qtMovie, (Boolean *)&attachedToCurrentThread, NULL);
//	if (err == noErr && !attachedToCurrentThread && (err = AttachMovieToCurrentThread(qtMovie)) == noErr)
//		attachedToCurrentThread = YES;
//	if (err != noErr && !onMainThread)
//		callToMainThread = YES;
    if ([movie respondsToSelector:@selector(attachToCurrentThread)])
        attachedToCurrentThread = [movie attachToCurrentThread];
	if (!onMainThread && !attachedToCurrentThread)
		callToMainThread = YES;
	
	if (callToMainThread)
	{
		[movieLock unlock];
		
		NSMutableDictionary	*dict = [NSMutableDictionary dictionary];
		
			// TBD: this could be done asynchronously
		[self performSelectorOnMainThread:_cmd withObject:dict waitUntilDone:YES];
		
		*identifier = [dict objectForKey:@"Identifier"];
		nextImage = [dict objectForKey:@"Image"];
	}
	else if (attachedToCurrentThread)
	{
		NSString	*nextIdentifier = nil;
//		TimeValue   nextInterestingTime = 0;
//		GetMovieNextInterestingTime(qtMovie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
//		
//		#ifdef DEBUG
//			OSErr		movieErr = GetMoviesError();
//			if (movieErr != noErr)
//				NSLog(@"Failed to get next interesting time. (%d)", movieErr);
//		#endif
//		
//		if (nextInterestingTime - currentTimeValue < minIncrement)
			currentTime = QTTimeIncrement(currentTime, minIncrement);
//		else
//			currentTimeValue = nextInterestingTime;
		
		if (QTTimeCompare(currentTime, duration) == NSOrderedAscending)
			nextIdentifier = [NSString stringWithFormat:@"%ld", currentTime.timeValue];
		
		if (nextIdentifier)
			nextImage = [self imageAtTime:currentTime];
		
		if (!nextImage)
		{
			nextIdentifier = nil;
//			GoToBeginningOfMovie(qtMovie);
		}
		
		if ([*identifier isKindOfClass:[NSMutableDictionary class]])
		{
			[*identifier setValue:nextIdentifier forKey:@"Identifier"];
			[*identifier setValue:nextImage forKey:@"Image"];
		}
		else
		{
			*image = nextImage;
			*identifier = nextIdentifier;
		}
		
		if (attachedToCurrentThread)
//			DetachMovieFromCurrentThread(qtMovie);
			[movie detachFromCurrentThread];
		
		[movieLock unlock];
		
		if (nextImage)
			[self performSelectorOnMainThread:@selector(setCurrentImage:) withObject:nextImage waitUntilDone:YES];
	}
	
	return error;
}


- (BOOL)canReenumerateImages
{
	return YES;
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
	NSImage	*image = nil;
	BOOL	onMainThread = pthread_main_np(), 
			callToMainThread = NO, 
			attachedToCurrentThread = NO;	// Will always be NO for the main thread.
//	Movie	qtMovie = [movie quickTimeMovie];
	
	[movieLock lock];
	
		// Try to attach the movie to this thread if necessary.  Call over to the main thread if that doesn't work.
//	OSErr	err = GetMovieThreadAttachState(qtMovie, (Boolean *)&attachedToCurrentThread, NULL);
//	if (err == noErr && !attachedToCurrentThread && (err = AttachMovieToCurrentThread(qtMovie)) == noErr)
//		attachedToCurrentThread = YES;
//	if (err != noErr && !onMainThread)
//		callToMainThread = YES;
    if ([movie respondsToSelector:@selector(attachToCurrentThread)])
        attachedToCurrentThread = [movie attachToCurrentThread];
	if (!onMainThread && !attachedToCurrentThread)
		callToMainThread = YES;
	
		// Get the image or call over to the main thread to do it.
	if (callToMainThread)
	{
		[movieLock unlock];
		
		NSMutableDictionary	*dict = [NSMutableDictionary dictionaryWithObject:identifier forKey:@"Identifier"];
		
		[self performSelectorOnMainThread:_cmd withObject:dict waitUntilDone:YES];
		
		image = [dict objectForKey:@"Image"];
	}
	else if (attachedToCurrentThread)
	{
		QTTime		identifierTime = duration;
		
		if ([identifier isKindOfClass:[NSMutableDictionary class]])
		{
			NSString	*realIdentifier = [(NSMutableDictionary *)identifier objectForKey:@"Identifier"];
			identifierTime.timeValue = [realIdentifier intValue];
			[(NSMutableDictionary *)identifier setValue:[self imageAtTime:identifierTime] forKey:@"Image"];
		}
		else
		{
			identifierTime.timeValue = [identifier intValue];
			image = [self imageAtTime:identifierTime];
		}
		
		if (attachedToCurrentThread)
			[movie detachFromCurrentThread];
		
		[movieLock unlock];
	}
    else
		[movieLock unlock];

	return image;
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
	NSMutableString	*description = [NSMutableString stringWithFormat:@"%@ [", [[moviePath lastPathComponent] stringByDeletingPathExtension]];
	float			timeIndex = (float)[identifier intValue] / (float)duration.timeScale;
	int				wholeSeconds = timeIndex,
					hours = wholeSeconds / 3600, 
					minutes = (wholeSeconds - hours * 60) / 60, 
					seconds = wholeSeconds % 60, 
					milliseconds = round(timeIndex - wholeSeconds) * 1000;
	
	if (hours > 0)
		[description appendFormat:@"%d:%02d:%02d.", hours, minutes, seconds];
	else //if (minutes > 0)
		[description appendFormat:@"%d:%02d.", minutes, seconds];
//	else
//		[description appendFormat:@"%d.", seconds];

	[description appendFormat:@"%03d", milliseconds];
	
	while ([description hasSuffix:@"0"] && ![description hasSuffix:@".0"])
		[description deleteCharactersInRange:NSMakeRange([description length] - 1, 1)];
	
	[description appendString:@"]"];
	
	return description;
}	


- (void)reset
{
	if (!movie)
		return;
	
	currentTime = QTZeroTime;

		// Set the initial image displayed in the sources table to the poster frame.
	[movieLock lock];
	
//	BOOL	attachedToCurrentThread = NO;
//	OSErr	err = GetMovieThreadAttachState(qtMovie, (Boolean *)&attachedToCurrentThread, NULL);
//	
//	if (err == noErr && !attachedToCurrentThread && (err = AttachMovieToCurrentThread(qtMovie)) == noErr)
//		attachedToCurrentThread = YES;
	
	
	// TODO: attach movie to current thread
	[self setCurrentImage:[movie posterImage]];
	// TODO: detach movie from current thread
	
//	if (attachedToCurrentThread)
//		[movie detachFromCurrentThread];
	
	[movieLock unlock];
}


- (void)dealloc
{
	[self setPath:nil];
	[movieLock release];
	[currentImage release];
	
	[super dealloc];
}


@end
