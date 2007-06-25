//
//  MacOSaiXImageSourcesView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourcesView.h"

#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXImageSourcesEditor.h"
#import "MacOSaiXImageSourceView.h"
#import "MacOSaiXMosaic.h"


@implementation MacOSaiXImageSourcesView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        imageSourceViews = [[NSMutableArray array] retain];
    }
	
    return self;
}


- (void)setImageSourcesEditor:(MacOSaiXImageSourcesEditor *)editor
{
	imageSourcesEditor = editor;
}


- (MacOSaiXImageSourcesEditor *)imageSourcesEditor
{
	return imageSourcesEditor;
}


- (BOOL)isFlipped
{
	return YES;
}


- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
}


- (NSArray *)viewsWithVisibleEditors
{
	NSMutableArray			*visibleEditors = [NSMutableArray array];
	NSEnumerator			*subViewEnumerator = [imageSourceViews objectEnumerator];
	MacOSaiXImageSourceView	*subView = nil;
	
	while (subView = [subViewEnumerator nextObject])
		if ([subView editorVisible])
			[visibleEditors addObject:subView];
	
	return visibleEditors;
}


- (NSArray *)selectedImageSourceEnumerators
{
	NSMutableArray			*selectedImageSourceEnumerators = [NSMutableArray array];
	NSEnumerator			*subViewEnumerator = [imageSourceViews objectEnumerator];
	MacOSaiXImageSourceView	*subView = nil;
	
	while (subView = [subViewEnumerator nextObject])
		if ([subView selected])
			[selectedImageSourceEnumerators addObject:[subView imageSourceEnumerator]];
	
	return selectedImageSourceEnumerators;
}


- (void)mouseDown:(NSEvent *)event
{
	NSPoint					mousePoint = [self convertPoint:[event locationInWindow] fromView:nil];
	NSEnumerator			*subViewEnumerator = [imageSourceViews objectEnumerator];
	MacOSaiXImageSourceView	*subView = nil;
	
	while (subView = [subViewEnumerator nextObject])
	{
		BOOL	subViewClicked = NSPointInRect(mousePoint, [subView frame]);
		
		if (([event modifierFlags] & NSCommandKeyMask) == 0)
			[subView setSelected:subViewClicked];
		else if (subViewClicked)
			[subView setSelected:![subView selected]];
	}
	
	[[self imageSourcesEditor] imageSourcesSelectionDidChange];
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (mosaic != inMosaic)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXMosaicDidChangeImageSourcesNotification object:mosaic];
		
		[mosaic release];
		mosaic = [inMosaic retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeImageSources:) 
													 name:MacOSaiXMosaicDidChangeImageSourcesNotification 
												   object:mosaic];
	}
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (void)mosaicDidChangeImageSources:(NSNotification *)notification
{
	[self updateImageSourceViews];
}


- (MacOSaiXImageSourceView *)viewForImageSource:(id<MacOSaiXImageSource>)imageSource
{
	NSEnumerator			*viewEnumerator = [imageSourceViews objectEnumerator];
	MacOSaiXImageSourceView	*view = nil;
	
	while (view = [viewEnumerator nextObject])
		if ([[view imageSourceEnumerator] imageSource] == imageSource)
			break;
	
	return view;
}


- (void)updateImageSourceViews
{
	NSRect							frameRect = [self frame];
	float							curY = 0.0;
	NSMutableArray					*newImageSourceViews = [NSMutableArray array];
	NSArray							*imageSourceEnumerators = [[self mosaic] imageSourceEnumerators];
	NSEnumerator					*imageSourceEnumeratorEnumerator = [imageSourceEnumerators objectEnumerator];
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
	
		// Get or create the view for each image source.
	while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
	{
		MacOSaiXImageSourceView	*imageSourceView = [self viewForImageSource:[imageSourceEnumerator imageSource]];
		
			// Reuse an existing view if possible otherwise create a new view.
		if (imageSourceView)
			[imageSourceViews removeObjectIdenticalTo:imageSourceView];
		else
		{
			imageSourceView = [[MacOSaiXImageSourceView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth(frameRect), 42.0)];
			[imageSourceView setAutoresizingMask:NSViewWidthSizable];
			[imageSourceView setImageSourceEnumerator:imageSourceEnumerator];
			[self addSubview:imageSourceView];
			[imageSourceView setPostsFrameChangedNotifications:YES];
		}
		
		frameRect.origin.y = curY;
		frameRect.size.height = NSHeight([imageSourceView frame]);
		[imageSourceView setFrame:frameRect];
		
		curY = NSMaxY(frameRect);
		
		[newImageSourceViews addObject:imageSourceView];
	}
	
		// Make this view big enough to contain all of the sub views.
	frameRect.size.height = curY;
	[self setFrame:frameRect];
	
		// Remove views for image sources that were removed from the mosaic.
	NSEnumerator			*viewEnumerator = [imageSourceViews objectEnumerator];
	MacOSaiXImageSourceView	*view = nil;
	while (view = [viewEnumerator nextObject])
		[view removeFromSuperview];
		
	[imageSourceViews removeAllObjects];
	[imageSourceViews addObjectsFromArray:newImageSourceViews];
	
	[self scrollPoint:NSZeroPoint];
}


- (void)tile
{
	NSEnumerator	*subViewEnumerator = [[self subviews] objectEnumerator];
	NSView			*subView = nil, 
					*previousSubView = nil;
	
	while (subView = [subViewEnumerator nextObject])
	{
		if (!previousSubView)
			[subView setFrameOrigin:NSMakePoint(NSMinX([subView frame]), 0.0)];
		else
			[subView setFrameOrigin:NSMakePoint(NSMinX([subView frame]), NSMaxY([previousSubView frame]))];
		
		previousSubView = subView;
	}
	
	NSRect			frameRect = [self frame];
	frameRect.size.height = NSMaxY([previousSubView frame]);
	[self setFrame:frameRect];
	
	[self setNeedsDisplay:YES];
}


- (void)dealloc
{
	[imageSourceViews release];
	
	[super dealloc];
}


@end
