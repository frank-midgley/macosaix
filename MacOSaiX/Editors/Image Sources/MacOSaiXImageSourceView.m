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


@implementation MacOSaiXImageSourceView


- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        disclosureButton = [[[NSButton alloc] initWithFrame:NSMakeRect(5.0, NSMaxY(frame) - 29.0, 16.0, 16.0)] autorelease];
		[disclosureButton setTarget:self];
		[disclosureButton setAction:@selector(toggleEditorShown:)];
		[disclosureButton setBezelStyle:NSDisclosureBezelStyle];
		[disclosureButton setButtonType:NSOnOffButton];
		[disclosureButton setImagePosition:NSImageOnly];
		[self addSubview:disclosureButton];
    }
	
    return self;
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
	
		// Draw the source's image.
	NSImage			*image = [imageSource image];
	[image compositeToPoint:NSMakePoint(NSMinX(bounds) + 26.0, NSMaxY(bounds) - 21.0 - ([image size].height / 2.0)) 
				  operation:NSCompositeSourceOver];
	
		// Draw the source's description.
	id				description = [imageSource briefDescription];
	
	if ([description isKindOfClass:[NSString class]])
	{
		NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:0.0] forKey:NSFontAttributeName];
	//	NSSize			descriptionSize = [description sizeWithAttributes:attributes];
		[description drawInRect:NSMakeRect(NSMinX(bounds) + 63.0, NSMaxY(bounds) - 37.0, NSWidth(bounds) - 68.0, 32.0) withAttributes:attributes];
	}
	else
	{
		[(NSAttributedString *)description drawInRect:NSMakeRect(NSMinX(bounds) + 63.0, NSMaxY(bounds) - 37.0, NSWidth(bounds) - 68.0, 32.0)];
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
			editorBox = [[[NSBox alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 100.0)] autorelease];
			[editorBox setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
			NSRect		contentFrame = [[editorBox contentView] frame];
			boxBorderSize = NSMakeSize(100.0 - NSWidth(contentFrame), 100.0 - NSHeight(contentFrame));
			
				// Create an editor for the image source.
			Class		plugIn = [(MacOSaiX *)[NSApp delegate] plugInForDataSourceClass:[imageSource class]];
			imageSourceEditor = [[[plugIn dataSourceEditorClass] alloc] initWithDelegate:self];
			
				// Set the height of the ut the editing view into the box.
			[editorBox setContentView:[imageSourceEditor editorView]];
			[editorBox sizeToFit];
		}
		
		NSRect		bounds = [self bounds];
		[editorBox setFrame:NSMakeRect(NSMinX(bounds) + 26.0, NSMinY(bounds) + 5.0, 
									   NSWidth(bounds) - 31.0, NSHeight([editorBox frame]))];
		[disclosureButton setFrameOrigin:NSMakePoint(5.0, NSMaxY(bounds) - 37.0)];
		
		[self addSubview:editorBox];
		
//		NSRect		frame = [self frame];
//		frame.size = ???
//		[self setFrame:];
	}
	else if (!flag && [editorBox superview])
	{
		[editorBox removeFromSuperview];
	}
}


- (BOOL)editorVisible
{
	return ([editorBox superview] != nil);
}


- (IBAction)toggleEditorShown:(id)sender
{
	
}


- (NSImage *)targetImage
{
	return nil;	//[[self mosaic] targetImage];
}


- (void)plugInSettingsDidChange:(NSString *)changeDescription
{
	// TODO: ???
}


- (void)dealloc
{
	[editorBox release];
	
	[super dealloc];
}


@end
