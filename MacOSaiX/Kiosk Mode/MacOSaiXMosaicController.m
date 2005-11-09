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
	tileRefreshLock = [[NSLock alloc] init];
	tilesToRefresh = [[NSMutableArray array] retain];
	
	[mosaicView setViewFade:1.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(scrollFrameDidChange:) 
												 name:NSViewFrameDidChangeNotification 
											   object:[mosaicView enclosingScrollView]];
}


- (void)setMosaic:(MacOSaiXMosaic *)mosaic
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTileImageDidChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileImageDidChangeNotification 
											   object:mosaic];
	
	[mosaicView setMosaic:mosaic];
}


- (void)scrollFrameDidChange:(NSNotification *)notification
{
	[mosaicView setFrame:[[[mosaicView enclosingScrollView] contentView] frame]];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	[tileRefreshLock lock];
		NSDictionary	*tileDict = [notification userInfo];
		
		if ([tilesToRefresh indexOfObject:tileDict] == NSNotFound)
			[tilesToRefresh addObject:tileDict];
		
		if (!refreshTilesTimer)
			[self performSelectorOnMainThread:@selector(startTileRefreshTimer) withObject:nil waitUntilDone:NO];
	[tileRefreshLock unlock];
}


- (void)startTileRefreshTimer
{
	[tileRefreshLock lock];
		if (!refreshTilesTimer && [tilesToRefresh count] > 0)
			refreshTilesTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5 
																  target:self 
															    selector:@selector(spawnRefreshThread:) 
															    userInfo:nil 
																 repeats:NO] retain];
	[tileRefreshLock unlock];
}


- (void)spawnRefreshThread:(NSTimer *)timer
{
	[tileRefreshLock lock];
			// Spawn a thread to refresh all tiles whose images have changed.
		if (!refreshTileThreadRunning)
		{
			refreshTileThreadRunning = YES;
			[NSApplication detachDrawingThread:@selector(refreshTiles) toTarget:self withObject:nil];
		}
		
		[refreshTilesTimer autorelease];
		refreshTilesTimer = nil;
	[tileRefreshLock unlock];
}


- (void)refreshTiles
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSDictionary		*tileToRefresh = nil;
	
	do
	{
		NSAutoreleasePool	*innerPool = [[NSAutoreleasePool alloc] init];
		
		tileToRefresh = nil;
		[tileRefreshLock lock];
			if ([tilesToRefresh count] > 0)
			{
				tileToRefresh = [[[tilesToRefresh objectAtIndex:0] retain] autorelease];
				[tilesToRefresh removeObjectAtIndex:0];
			}
		[tileRefreshLock unlock];
		
		if (tileToRefresh)
			[mosaicView refreshTile:[tileToRefresh objectForKey:@"Tile"] 
					  previousMatch:[tileToRefresh objectForKey:@"Previous Match"]];
		
		[innerPool release];
	} while (tileToRefresh);
	
	refreshTileThreadRunning = NO;
	
	[pool release];
}


- (void)dealloc
{
	[tileRefreshLock release];
	[tilesToRefresh release];
	
	[super dealloc];
}


@end
