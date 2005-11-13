//
//  MacOSaiXMosaicController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXMosaicController.h"


@implementation MacOSaiXMosaicController


- (NSString *)windowNibName
{
	return @"Mosaic";
}


- (void)awakeFromNib
{
	[mosaicView setViewFade:1.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(scrollFrameDidChange:) 
												 name:NSViewFrameDidChangeNotification 
											   object:[mosaicView enclosingScrollView]];
}


- (void)setMosaic:(MacOSaiXMosaic *)mosaic
{
	[mosaicView setMosaic:mosaic];
}


- (void)scrollFrameDidChange:(NSNotification *)notification
{
	[mosaicView setFrame:[[[mosaicView enclosingScrollView] contentView] frame]];
}


@end
