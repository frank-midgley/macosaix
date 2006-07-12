//
//  iSightImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "iSightImageSourceController.h"
#import "iSightImageSource.h"


@implementation MacOSaiXiSightImageSourceController


- (void)saveSettings
{
	NSMutableDictionary	*settings = [[[NSUserDefaults standardUserDefaults] objectForKey:@"iSight Image Source"] mutableCopy];
	
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"iSight Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[settings release];
}


- (void)awakeFromNib
{
//	NSDictionary	*settings = [[NSUserDefaults standardUserDefaults] objectForKey:@"iSight Image Source"];
	
	[self saveSettings];	// must be done after setting the content of the controller
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iSight Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(380.0, 300.0);
}


- (NSSize)maximumSize
{
	return [self minimumSize];
}


- (NSResponder *)firstResponder
{
	return sourcePopUp;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
	[sourcePopUp selectItemAtIndex:[sourcePopUp indexOfItemWithRepresentedObject:[currentImageSource source]]];
	
		// Set up to get notified when the window changes size so that we can adjust the
		// width of the movie view in a way that preserves the movie's aspect ratio.
//	[[NSNotificationCenter defaultCenter] addObserver:self 
//											 selector:@selector(movieSuperViewDidChangeFrame:) 
//												 name:NSViewFrameDidChangeNotification 
//											   object:[movieView superview]];
	
	previewTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 
													 target:self 
												   selector:@selector(updatePreview:) 
												   userInfo:nil 
													repeats:YES] retain];
}


- (void)updatePreview:(NSTimer *)timer
{
	[previewView setImage:[currentImageSource nextImageAndIdentifier:NULL]];
}


- (BOOL)settingsAreValid
{
	return YES;
}


- (void)editingComplete
{
//	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
	
	[previewTimer invalidate];
	[previewTimer release];
	previewTimer = nil;
}


- (IBAction)setSource:(id)sender
{
}


#pragma mark -


- (void)dealloc
{
//	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[currentImageSource release];
	
	[super dealloc];
}


@end
