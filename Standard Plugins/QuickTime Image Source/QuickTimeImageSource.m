#import <AppKit/AppKit.h>
#import <QuickTime/QuickTime.h>
#import "QuickTimeImageSource.h"


@implementation QuickTimeImageSource


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
	return _curTimeValue < GetMovieDuration(_movie);
}


- (id)nextImageIdentifier
{
    _curTimeValue += 5;	//_duration;
//    GetMovieNextInterestingTime (_movie, nextTimeMediaSample, 0, nil, _curTimeValue, 1, &_curTimeValue, &_duration);
//    NSLog(@"Next interesting time=%@", [NSNumber numberWithLong:_curTimeValue]);
	return [NSNumber numberWithLong:_curTimeValue];
}


- (NSImage *)imageForIdentifier:(id)identifier
{
	TimeValue	requestedTime = [identifier longValue];
	
	if (requestedTime > GetMovieDuration(_movie)) return nil;
	
	PicHandle	picHandle = GetMoviePict(_movie, requestedTime);
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
