/*
	FlickrImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import "FlickrImageSource.h"

@interface FlickrImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView			*editorView;
	IBOutlet NSTextField	*queryField;
	IBOutlet NSMatrix		*queryTypeMatrix;

	NSButton				*okButton;
	FlickrImageSource		*currentImageSource;
}

- (IBAction)visitFlickr:(id)sender;
- (IBAction)setQueryType:(id)sender;

@end
