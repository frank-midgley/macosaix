//
//  MacOSaiXImageSourceView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourceView.h"

#import "MacOSaiX.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageSourcesView.h"


@implementation MacOSaiXImageSourceView


- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        disclosureButton = [[[NSButton alloc] initWithFrame:NSMakeRect(5.0, 13.0, 16.0, 16.0)] autorelease];
		[disclosureButton setTarget:self];
		[disclosureButton setAction:@selector(toggleEditorShown:)];
		[disclosureButton setBezelStyle:NSDisclosureBezelStyle];
		[disclosureButton setButtonType:NSOnOffButton];
		[disclosureButton setImagePosition:NSImageOnly];
		[self addSubview:disclosureButton];
    }
	
    return self;
}


- (BOOL)isFlipped
{
	return YES;
}


- (void)setImageSource:(id<MacOSaiXImageSource>)source
{
	if (source != imageSource)
	{
		[imageSource release];
		imageSource = [source retain];
	}
}


- (id<MacOSaiXImageSource>)imageSource
{
	return imageSource;
}


- (void)drawRect:(NSRect)rect
{
	NSRect			bounds = [self bounds];
	
	if ([self selected])
	{
		[[NSColor selectedTextBackgroundColor] set];
		NSRectFill(rect);
	}
	
		// Draw the source's image.
	NSImage			*image = [imageSource image];
	[image compositeToPoint:NSMakePoint(NSMinX(bounds) + 26.0, 21.0 + ([image size].height / 2.0)) 
				  operation:NSCompositeSourceOver];
	
		// Draw the source's description.
	id				description = [imageSource briefDescription];
	
	if ([description isKindOfClass:[NSString class]])
	{
		NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:0.0] forKey:NSFontAttributeName];
	//	NSSize			descriptionSize = [description sizeWithAttributes:attributes];
		[description drawInRect:NSMakeRect(NSMinX(bounds) + 63.0, 13.0, NSWidth(bounds) - 68.0, 32.0) withAttributes:attributes];
	}
	else
	{
		[(NSAttributedString *)description drawInRect:NSMakeRect(NSMinX(bounds) + 63.0, 13.0, NSWidth(bounds) - 68.0, 32.0)];
	}
	
	// TODO: draw the image count
	
	[super drawRect:rect];
}


- (void)setSelected:(BOOL)flag
{
	if (selected != flag)
	{
		selected = flag;
		[self setNeedsDisplay:YES];
	}
}


- (BOOL)selected
{
	return selected;
}


- (void)setEditorVisible:(BOOL)flag
{
	if (flag && ![editorBox superview])
	{
		if (!editorBox)
		{
			// This is the first time this source has been disclosed.
			
				// Create the editor box with a generic frame and figure out the size of its border.
			editorBox = [[NSBox alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 100.0)];
			[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
			[editorBox setTitlePosition:NSNoTitle];
			NSRect		boxFrame = [editorBox frame], 
						contentFrame = [[editorBox contentView] frame];
			boxBorderSize = NSMakeSize(NSWidth(boxFrame) - NSWidth(contentFrame), 
									   NSHeight(boxFrame) - NSHeight(contentFrame));
			
				// Create an editor for the image source.
			Class		plugIn = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[imageSource class]];
			imageSourceEditor = [[[plugIn editorClass] alloc] initWithDelegate:self];
			
				// Size the box to fit the editor view and install it.
			NSView		*editorView = [imageSourceEditor editorView];
			[editorBox setFrame:NSMakeRect(0.0, 0.0, 
										   NSWidth([editorView frame]) + boxBorderSize.width, 
										   NSHeight([editorView frame]) + boxBorderSize.height)];
			[editorBox setContentView:editorView];
		}
		
		NSRect		bounds = [self bounds];
		[editorBox setFrame:NSMakeRect(NSMinX(bounds) + 26.0, 42.0, 
									   NSWidth(bounds) - 31.0, NSHeight([editorBox frame]))];
		
		[self addSubview:editorBox];
		
		[editorBox setAutoresizingMask:NSViewWidthSizable];
		[self setFrameSize:NSMakeSize(NSWidth([self bounds]), NSHeight([self bounds]) + NSHeight([editorBox frame]))];
		[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		
		[disclosureButton setState:NSOnState];
		
		[imageSourceEditor editDataSource:[self imageSource]];
		
		[(MacOSaiXImageSourcesView *)[self superview] tile];
	}
	else if (!flag && [editorBox superview])
	{
		[imageSourceEditor editingDidComplete];
		
		[editorBox removeFromSuperview];
		
		[self setFrameSize:NSMakeSize(NSWidth([self bounds]), 42.0)];
		
		[disclosureButton setState:NSOffState];
		
		[(MacOSaiXImageSourcesView *)[self superview] tile];
	}
}


- (BOOL)editorVisible
{
	return ([editorBox superview] != nil);
}


- (IBAction)toggleEditorShown:(id)sender
{
	[self setEditorVisible:![self editorVisible]];
}


- (NSImage *)targetImage
{
	return nil;	//[[self mosaic] targetImage];
}


- (void)plugInSettingsDidChange:(NSString *)changeDescription
{
	[self setNeedsDisplay:YES];
}


- (NSSize)minimumEditorSize
{
	NSSize	minSize = [imageSourceEditor minimumSize];
	
	minSize.width += boxBorderSize.width + 31.0;
	
	return minSize;
}


- (void)dealloc
{
	[editorBox release];
	
	[super dealloc];
}


@end
