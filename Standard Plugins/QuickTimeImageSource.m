#import <AppKit/AppKit.h>
#import <QuickTime/QuickTime.h>
#import "QuickTimeImageSource.h"
#import <pthread.h>


static NSRecursiveLock  *sQuickTimeLock = nil;


@interface QuickTimeImageSource (PrivateMethods)
- (void)setCurrentImage:(NSImage *)image;
@end


@implementation QuickTimeImageSource


- (void)lockQuickTime
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


- (void)unlockQuickTime
{
//	void (*funcPtr)() = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.QuickTime")),
//															 CFSTR("ExitMoviesOnThread"));
//	if (funcPtr)
//		funcPtr();
//    ExitMovies();
    
	[sQuickTimeLock unlock];
}


- (id)initWithPath:(NSString *)path
{
	if (self = [super init])
	{
		FSRef		movieRef;
		OSStatus	status = FSPathMakeRef([path fileSystemRepresentation], &movieRef, NULL);
	
		moviePath = [path retain];
		if (status == noErr)
		{
			FSSpec	movieSpec;
			OSErr	err = FSGetCatalogInfo(&movieRef, kFSCatInfoNone, NULL, NULL, &movieSpec, NULL);
		
			if (err == noErr)
			{
				short	theRefNum;
	
				EnterMovies();
				err = OpenMovieFile(&movieSpec, &theRefNum, fsRdPerm);
				if (err == noErr)
				{
					err = NewMovieFromFile(&movie, theRefNum, 0, NULL, newMovieActive, NULL);
					
					if (err == noErr)
					{
						Rect		movieBounds;
						
						GetMovieBox(movie, &movieBounds);
						OffsetRect(&movieBounds, -movieBounds.left, -movieBounds.top);
						SetMovieBox(movie, &movieBounds);
						NSLog(@"Movie size:%d, %d", movieBounds.right, movieBounds.bottom);
						
                        minIncrement = GetMovieTimeScale(movie) / 10;   // equals 10 fps
						duration = GetMovieDuration(movie);
						
						[self setCurrentImage:[self imageForIdentifier:[NSNumber numberWithLong:GetMoviePosterTime(movie)]]];
					}
					
					CloseMovieFile(theRefNum);
				}
			}
		}
		if (!movie)
		{
			[self autorelease];
			self = nil;
		}
	}
    return self;
}


- (void)setCurrentImage:(NSImage *)image
{
	[currentImage autorelease];
	currentImage = [[NSImage alloc] initWithSize:NSMakeSize(64.0, 64.0)];
	
	[currentImage lockFocus];
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
	[currentImage unlockFocus];
}


	// return the image to be displayed in the list of image sources
- (NSImage *)image;
{
    return currentImage ? currentImage : [[NSWorkspace sharedWorkspace] iconForFile:moviePath];
}


	// return the text to be displayed in the list of image sources
- (NSString *)descriptor
{
    return moviePath;
}


- (BOOL)hasMoreImages
{
	return currentTimeValue < duration;
}


- (id)nextImageIdentifier
{
	NSMutableArray	*parameters = [NSMutableArray array];
	
	[self performSelectorOnMainThread:@selector(nextImageIdentifierOnMainThread:) 
						   withObject:parameters
						waitUntilDone:YES];
	
	return ([parameters count] > 0 ? [parameters objectAtIndex:0] : nil);
}


- (void)nextImageIdentifierOnMainThread:(NSMutableArray *)parameters
{
    TimeValue   nextInterestingTime = 0;
    
	GetMovieNextInterestingTime (movie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
	OSErr   err = GetMoviesError();
	
	if (err != noErr)
		NSLog(@"Error %d getting next interesting time.", err);
	else
	{
		if (nextInterestingTime - currentTimeValue < minIncrement)
			currentTimeValue += minIncrement;
		else
			currentTimeValue = nextInterestingTime;
		_imageCount++;
	}
    
//    NSLog(@"Next interesting time=%@", [NSNumber numberWithLong:currentTimeValue]);
	
	[parameters addObject:[NSNumber numberWithLong:currentTimeValue]];
}


- (NSImage *)imageForIdentifier:(id)identifier
{
	NSImage		*imageAtTimeValue = [[[NSImage alloc] initWithSize:NSMakeSize(64, 64)] autorelease];
	
	[self performSelectorOnMainThread:@selector(imageForIdentifierOnMainThread:) 
						   withObject:[NSArray arrayWithObjects:identifier, imageAtTimeValue, nil]
						waitUntilDone:YES];
	
	if ([identifier longValue] == currentTimeValue)
		[self setCurrentImage:imageAtTimeValue];
	
	return imageAtTimeValue;
}


- (void)imageForIdentifierOnMainThread:(NSArray *)parameters
{
	TimeValue	requestedTime = [[parameters objectAtIndex:0] longValue];
	
	if (requestedTime <= duration)
	{
		PicHandle	picHandle = GetMoviePict(movie, requestedTime);
		OSErr       err = GetMoviesError();
		if (err != noErr)
			NSLog(@"Error %d getting movie picture.", err);
		else if (picHandle)
		{
			NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:[NSData dataWithBytes:*picHandle 
																						length:GetHandleSize((Handle)picHandle)]];
			NSImage			*imageAtTimeValue = [parameters objectAtIndex:1];
			
			[imageAtTimeValue setScalesWhenResized:YES];
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
}


- (void)dealloc
{
	[moviePath release];
	
	[super dealloc];
}


@end
