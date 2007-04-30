//
//  MacOSaiXImageSourcesView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourcesView.h"

#import "MacOSaiXImageSourceView.h"
#import "MacOSaiXMosaic.h"


@implementation MacOSaiXImageSourcesView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}


- (BOOL)isFlipped
{
	return YES;
}


- (void)drawRect:(NSRect)rect
{
    // Drawing code here.
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
		if ([view imageSource] == imageSource)
			break;
	
	return view;
}


- (void)updateImageSourceViews
{
	NSRect					frameRect = [self frame];
	float					curY = 0.0;
	NSMutableArray			*newImageSourceViews = [NSMutableArray array];
	NSArray					*imageSources = [[self mosaic] imageSources];
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	
		// Get or create the view for each image source.
	while (imageSource = [imageSourceEnumerator nextObject])
	{
		MacOSaiXImageSourceView	*imageSourceView = [self viewForImageSource:imageSource];
		
			// Reuse an existing view if possible otherwise create a new view.
		if (imageSourceView)
			[imageSourceViews removeObjectIdenticalTo:imageSourceView];
		else
		{
			imageSourceView = [[MacOSaiXImageSourceView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth(frameRect), 42.0)];
			[imageSourceView setImageSource:imageSource];
			[self addSubview:imageSourceView];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(imageSourceViewDidChangeFrame:) 
														 name:NSViewFrameDidChangeNotification 
													   object:imageSourceView];
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
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:view];
		[view removeFromSuperview];
	}
		
	[imageSourceViews removeAllObjects];
	[imageSourceViews addObjectsFromArray:newImageSourceViews];
}


- (void)imageSourceViewDidChangeFrame:(NSNotification *)notification
{
	
}


@end
