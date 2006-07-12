/*
	iSightImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "iSightImageSource.h"
#import "iSightImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <Carbon/Carbon.h>
#import <pthread.h>


@interface MacOSaiXiSightImageSource (PrivateMethods)
- (void)setCurrentImage:(NSImage *)image;
- (void)nextImageAndIdentifierOnMainThread:(NSMutableDictionary *)parameters;
- (void)imageForIdentifierOnMainThread:(NSArray *)parameters;
@end


//static pascal OSErr GrabberDataProc(SGChannel c, Ptr p, long len, long *offset, long chRefCon, TimeValue time, 
//									short writeType, long refCon)
//{
//	return [(MacOSaiXiSightImageSource*)refCon handleData:p length:len time:time];
//}
//
//static void TrackDecompression(void *decompressionTrackingRefCon,
//                               OSStatus result,
//                               ICMDecompressionTrackingFlags decompressionTrackingFlags,
//                               CVPixelBufferRef pixelBuffer,
//                               TimeValue64 displayTime,
//                               TimeValue64 displayDuration,
//                               ICMValidTimeFlags validTimeFlags,
//                               void *sourceFrameRefCon, void *reserved)
//{
//}


@implementation MacOSaiXiSightImageSource


+ (NSImage *)image
{
	NSImage		*image = [NSImage imageNamed:@"iSight"];
	
	if (!image)
	{
		NSString	*imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"iSight"];
		image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
	}
	
	return image;
}


+ (Class)editorClass
{
	return [MacOSaiXiSightImageSourceController class];
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
	}

    return self;
}


- (id)initWithSource:(NSString *)source
{
	if (self = [self init])
	{
		[self setSource:source];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<SOURCE NAME=\"%@\"/>", 
									  [[self source] stringByEscapingXMLEntites]];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"SOURCE"])
	{
		[self setSource:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
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
	MacOSaiXiSightImageSource	*copy = [[MacOSaiXiSightImageSource allocWithZone:zone] initWithSource:[self source]];
	
	return copy;
}


//- (void)taskGrabber
//{
//	static const double idleInterval = 1.0 / 60.0;
//	
//	SGIdle(grabber);
//	
//	if (!timer)
//		timer = [[NSTimer scheduledTimerWithTimeInterval:idleInterval 
//												  target:self 
//												selector:@selector(taskGrabber) 
//												userInfo:self 
//												 repeats:YES] retain];
//}


- (NSString *)source
{
	return videoSource;
}


- (void)setSource:(NSString *)source
{
	[videoSource autorelease];
	videoSource = [source copy];
	
	OSStatus			err = noErr;
	VideoDigitizerError	vdError = noErr;
	Rect		bounds = {0, 0, 240, 320};
	
	grabber = OpenDefaultComponent(SeqGrabComponentType, 0);
	
	if (grabber)
		err = SGInitialize(grabber);
		
	if (err == noErr)
		err = SGSetDataRef(grabber, 0, 0, seqGrabDontMakeMovie);
	
	if (err == noErr)
		err = SGNewChannel(grabber, VideoMediaType, &channel);
	
	if (err == noErr)
		err = SGSetFrameRate(channel, 0);
			
	if (err == noErr)
	{
		err = QTNewGWorld(&offscreen, 32, &bounds, nil, nil, 0);
		LockPixels(GetGWorldPixMap(offscreen));
	}
	
	if (err == noErr)
		err = SGSetGWorld(channel, offscreen, GetGWorldDevice(offscreen));
	
	if (err == noErr)
		err = SGSetChannelBounds(channel, &bounds);
	
	if (err == noErr)
		err = SGSetChannelUsage(channel, seqGrabRecordPreferQualityOverFrameRate);
	
//	if (err == noErr)
//		err = SGSetDataProc(grabber, &GrabberDataProc, (long)self);
	
	if (err == noErr)
		digitizer = SGGetVideoDigitizerComponent(channel);
	
	if (digitizer)
	{
//		vdError = VDSetTimeBase(digitizer, NewTimeBase());
		
		VDCompressionListHandle	compressionList = (VDCompressionListHandle) NewHandle(4);
		if (vdError == noErr)
			vdError = VDGetCompressionTypes(digitizer, compressionList);
		
		if (vdError == noErr)
			vdError = VDSetCompressionOnOff(digitizer, TRUE);
		
		if (vdError == noErr)
			vdError = VDSetCompression(digitizer, (*compressionList)->cType, 8, &bounds, 
									 codecNormalQuality, 0, 0);
		
		imageDescHandle = (ImageDescriptionHandle) NewHandle(4);
		if (vdError == noErr)
			vdError = VDGetImageDescription(digitizer, imageDescHandle);
		
		if (vdError != noErr)
			err = SGStartRecord(grabber);
	}
	
//	[self taskGrabber];
}


- (float)aspectRatio
{
	return aspectRatio;
}


- (void)setCurrentImage:(NSImage *)image
{
	NSImage	*newImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
	
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
			}
			else
			{
				float	scaledWidth = 32.0 / [image size].height * [image size].width;
				[image drawInRect:NSMakeRect((32.0 - scaledWidth) / 2.0, 0, scaledWidth, 64)
						 fromRect:NSZeroRect
						operation:NSCompositeCopy
						 fraction:1.0];
			}
	}
	@catch (NSException *exception)
	{
		#ifdef DEBUG
			NSLog(@"iSight Image Source: Could not set current image.");
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
		image = [NSImage imageNamed:@"iSight"];
	
	return image;
}


	// return the text to be displayed in the list of image sources
- (id)descriptor
{
    return ([videoSource length] > 0) ? videoSource : @"No video source has been specified";
}


- (BOOL)hasMoreImages
{
	return YES;
}


//- (OSErr)handleData:(void*)data length:(long)length time:(TimeValue)timeValue
//{
//	OSStatus			err = noErr;
//	ICMFrameTimeRecord	now = {0};
//	
//		// Create our decompression session the first time through
//	if (imageDescription == nil)
//	{
//        // create a tracking callback record, this is mandatory
//        // the TrackingCallback is used to track information about queued frames,
//        // pixel buffers, errors, status and so on about the decompressed frames
//		ICMDecompressionTrackingCallbackRecord trackingCallback = {&TrackDecompression, self};
//		
//		err = SGGetChannelTimeScale(channel, &timeScale);
//		require_noerr(err, bail);
//		
//		imageDescription = (ImageDescriptionHandle)NewHandle(0);
//		err = SGGetChannelSampleDescription(channel, Handle(imageDescription));
//		require_noerr(err, bail);
//		
//        // create a decompression session for our visual context, Frames will be output to a visual context
//        // If desired, the trackingCallback may be used to add additional data to pixel buffers before they are sent to the visual context
//        // or to keep track of the status of the decompression
//		err = ICMDecompressionSessionCreateForVisualContext(NULL, imageDescription, NULL, visualContext, &trackingCallback, &session);
//		require_noerr(err, bail);
//	}
//	
//	// Fill in the frame time
//	now.recordSize = sizeof(ICMFrameTimeRecord);
//	*(TimeValue64*)&now.value = timeValue;
//	now.scale = timeScale;
//	now.rate = fixed1;
//	now.decodeTime = timeValue;
//	now.frameNumber = frameNumber++;
//	now.flags = icmFrameTimeIsNonScheduledDisplayTime;
//	
//	// Enqueue frame
//	err = ICMDecompressionSessionDecodeFrame(session, (const UInt8*)data, length, NULL, &now, self);
//	require_noerr(err, bail);
//	
//	// Force frame out
//	err = ICMDecompressionSessionSetNonScheduledDisplayTime(session, *(long long int*)&now.value, timeScale, 0);
//	require_noerr(err, bail);
//}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;
{
	NSImage				*nextImage = nil;
	
	VideoDigitizerError	error = VDCompressOneFrameAsync(digitizer);
	
	while (1)
	{
		//SGIdle(grabber);
		
		UInt8		frameCount;
		Ptr			buffer = NULL;
		long		bufferSize = 0;
		UInt8		similarity = 0;
		TimeRecord	tr;
		
		error = VDCompressDone(digitizer, &frameCount, &buffer, &bufferSize, &similarity, &tr);
		
		if (error == noErr && buffer && frameCount != 0)
		{
			NSRect			windowRect = NSMakeRect(0.0, 0.0, 320.0, 240.0);
			NSWindow		*window = [[NSWindow alloc] initWithContentRect:windowRect 
																  styleMask:NSBorderlessWindowMask 
																	backing:NSBackingStoreBuffered 
																	  defer:NO];
//			[window orderOut:self];
			CGrafPtr		windowPort = GetWindowPort([window windowRef]);
			LockPortBits(windowPort);
			PixMapHandle	pmh = GetPortPixMap(windowPort);
			
			Rect			destRect = {0, 0, 240, 320};
			error = DecompressImage(buffer, 
									imageDescHandle,
									pmh, 
									NULL, // copy the full source rect
									&destRect, 
									srcCopy, 
									NULL);	// no mask
			error = VDReleaseCompressBuffer(digitizer, buffer);
			UnlockPortBits(windowPort);
			
			[[window contentView] lockFocus];
			NSBitmapImageRep	*bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:windowRect];
			[window release];
			
			nextImage = [[NSImage alloc] initWithSize:[bitmapRep size]];
			[nextImage addRepresentation:bitmapRep];
			[bitmapRep release];
			
//			[window close];
//			[window release];
			
			// TODO: create identifier from time record
			break;
		}
	}
	
	if (nextImage)
		[self setCurrentImage:nextImage];
	
	if (identifier)
		*identifier = nil;
	
	return nextImage;
}


- (BOOL)canRefetchImages
{
	return NO;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	return nil;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	return nil;
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
	// TODO: return a timestamp
	
	return nil;
}	


- (void)reset
{
}


- (void)dealloc
{
//	if (timer != nil)
//	{
//		[timer invalidate];
//		[timer release];
//	}
//	
//	if (grabber != NULL)
//		SGStop(grabber);
//	
//	ICMDecompressionSessionRelease(session);
//	
//	if (imageDescription != nil)
//		DisposeHandle(Handle(imageDescription));
//	
//	if (channel != nil)
//		SGDisposeChannel(grabber, channel);
//	
//	if (grabber != nil)
//		CloseComponent(grabber);
//	
//	if (offscreen != nil)
//		DisposeGWorld(offscreen);
	
	[self setSource:nil];
	[currentImage release];
	
	[super dealloc];
}


@end
