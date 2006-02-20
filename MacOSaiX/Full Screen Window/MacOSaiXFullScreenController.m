//
//  MacOSaiXFullScreenController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXFullScreenController.h"


@implementation MacOSaiXFullScreenController


- (NSString *)windowNibName
{
	return @"Full Screen";
}


- (void)awakeFromNib
{
	[mosaicView setFade:1.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(scrollFrameDidChange:) 
												 name:NSViewFrameDidChangeNotification 
											   object:[mosaicView enclosingScrollView]];
}


- (void)setMosaicView:(MosaicView *)view
{
	if (mosaicView)
	{
			// Swap in the new view.
		[view setFrame:[mosaicView frame]];
		[[mosaicView superview] addSubview:view];
		[mosaicView removeFromSuperview];
	}
	
	mosaicView = view;
}


- (void)setMosaic:(MacOSaiXMosaic *)mosaic
{
	[mosaicView setMosaic:mosaic];
}


- (void)setClosesOnKeyPress:(BOOL)flag
{
	closesOnKeyPress = flag;
}


- (BOOL)closesOnKeyPress
{
	return closesOnKeyPress;
}


- (void)scrollFrameDidChange:(NSNotification *)notification
{
	[mosaicView setFrame:[[[mosaicView enclosingScrollView] contentView] frame]];
}


@end
