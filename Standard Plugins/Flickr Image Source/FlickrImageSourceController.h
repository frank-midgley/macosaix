/*
	FlickrImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

@class MacOSaiXFlickrImageSource;

@interface MacOSaiXFlickrImageSourceEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>		delegate;
	
	IBOutlet NSView					*editorView;
	IBOutlet NSTextField			*queryField;
	IBOutlet NSMatrix				*queryTypeMatrix;
	
	IBOutlet NSTextField			*matchingPhotosCount;
	IBOutlet NSProgressIndicator	*matchingPhotosIndicator;
	NSTimer							*matchingPhotosTimer;
	
	MacOSaiXFlickrImageSource		*currentImageSource;
}

- (IBAction)visitFlickr:(id)sender;
- (IBAction)setQueryType:(id)sender;

@end
