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
	
	void (*funcPtr)(int) = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.QuickTime")),
															 CFSTR("EnterMoviesOnThread"));
	if (funcPtr)
		funcPtr(1L << 1);

	[sQuickTimeLock lock];
}


- (void)unlockQuickTime
{
	void (*funcPtr)() = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.QuickTime")),
															 CFSTR("ExitMoviesOnThread"));
	if (funcPtr)
		funcPtr();
	[sQuickTimeLock unlock];
}


- (id)initWithPath:(NSString *)path
{
	self = [super init];
	if (self)
	{
		FSRef		movieRef;
		OSStatus	status = FSPathMakeRef([path fileSystemRepresentation], &movieRef, NULL);
	
		_moviePath = [path retain];
		_curTimeValue = 0;
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
					err = NewMovieFromFile(&_movie, theRefNum, 0, NULL, newMovieActive, NULL);
					
					if (err == noErr)
					{
						Rect		movieBounds;
						
						GetMovieBox(_movie, &movieBounds);
						OffsetRect(&movieBounds, -movieBounds.left, -movieBounds.top);
						SetMovieBox(_movie, &movieBounds);
						NSLog(@"Movie size:%d, %d", movieBounds.right, movieBounds.bottom);
						
						_duration = GetMovieDuration(_movie);
					}
					
					CloseMovieFile(theRefNum);
				}
			}
		}
		if (!_movie)
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
    return [[NSWorkspace sharedWorkspace] iconForFile:_moviePath];
}


	// return the text to be displayed in the list of image sources
- (NSString *)descriptor
{
    return _moviePath;
}


- (BOOL)hasMoreImages
{
	return _curTimeValue < _duration;
}


- (id)nextImageIdentifier
{
	[self lockQuickTime];
		GetMovieNextInterestingTime (_movie, nextTimeStep, 0, nil, _curTimeValue, 1, &_curTimeValue, &_duration);
		OSErr   err = GetMoviesError();
	[self unlockQuickTime];
	
	if (err != noErr)
		NSLog(@"Error %d getting next interesting time.", err);
	
    NSLog(@"Next interesting time=%@", [NSNumber numberWithLong:_curTimeValue]);
	
	return [NSNumber numberWithLong:_curTimeValue];
}


- (NSImage *)imageForIdentifier:(id)identifier
{
	TimeValue	requestedTime = [identifier longValue];
	
	if (requestedTime > _duration) return nil;
	
//	if (!pthread_main_np())
//		CSSetComponentsThreadMode(kCSAcceptThreadSafeComponentsOnlyMode);
	
	[self lockQuickTime];
		PicHandle	picHandle = GetMoviePict(_movie, requestedTime);
	[self unlockQuickTime];
	OSErr   err = GetMoviesError();
	if (err != noErr)
		NSLog(@"Error %d getting movie picture.", err);
	
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
	[_moviePath release];
}


@end
