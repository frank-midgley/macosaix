#import <AppKit/AppKit.h>
#import <QuickTime/QuickTime.h>
#import "QuickTimeImageSource.h"
#import <pthread.h>


static NSRecursiveLock  *sQuickTimeLock = nil;


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
						
                        minIncrement = GetMovieTimeScale(movie) / 30;   // at most 30 frames/second
						duration = GetMovieDuration(movie);
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


	// return the image to be displayed in the list of image sources
- (NSImage *)image;
{
    return [[NSWorkspace sharedWorkspace] iconForFile:moviePath];
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
    TimeValue   nextInterestingTime = 0;
    
	[self lockQuickTime];
		GetMovieNextInterestingTime (movie, nextTimeStep, 0, nil, currentTimeValue, 1, &nextInterestingTime, nil);
		OSErr   err = GetMoviesError();
	[self unlockQuickTime];
	
	if (err != noErr)
    {
		NSLog(@"Error %d getting next interesting time.", err);
        return nil;
    }
	
    if (nextInterestingTime - currentTimeValue < minIncrement)
        currentTimeValue += minIncrement;
    else
        currentTimeValue = nextInterestingTime;
    
//    NSLog(@"Next interesting time=%@", [NSNumber numberWithLong:currentTimeValue]);
	
	return [NSNumber numberWithLong:currentTimeValue];
}


- (NSImage *)imageForIdentifier:(id)identifier
{
	TimeValue	requestedTime = [identifier longValue];
	
	if (requestedTime > duration) return nil;
	
	[self lockQuickTime];
		PicHandle	picHandle = GetMoviePict(movie, requestedTime);
        OSErr       err = GetMoviesError();
	[self unlockQuickTime];
	if (err != noErr)
    {
		NSLog(@"Error %d getting movie picture.", err);
        return nil;
    }
	
	NSImage		*imageAtTimeValue = nil;
	Rect		movieBounds = {0, 0, 0, 0};
	
	if (picHandle)
	{
		NSPICTImageRep	*imageRep = [NSPICTImageRep imageRepWithData:[NSData dataWithBytes:*picHandle 
																					length:GetHandleSize((Handle)picHandle)]];
		
		movieBounds.top += 1;
		if (imageAtTimeValue = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease])
		{
			[imageAtTimeValue setScalesWhenResized:YES];
			NS_DURING
				[imageAtTimeValue lockFocus];
					[imageRep drawAtPoint:NSMakePoint(0,0)];
				[imageAtTimeValue unlockFocus];
			NS_HANDLER
				NSLog(@"QuickTime Image Source: Could not lock focus on image");
			NS_ENDHANDLER
		}
		
		KillPicture(picHandle);
	}
    return imageAtTimeValue;
}


- (void)dealloc
{
	[moviePath release];
}


@end
