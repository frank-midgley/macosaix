//
//  MacOSaiXBitmapExportEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapExportEditor.h"

#import "MacOSaiXBitmapExportSettings.h"


@implementation MacOSaiXBitmapExportEditor


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!editorView)
	{
		[NSBundle loadNibNamed:@"Bitmap Export" owner:self];
		
		// TODO: #ifdef out for i386 build?
		// if (!CGImageDestinationCreateWithURL)
		//	[[formatMatrix cellAtRow:1 column:0] setEnabled:NO];
	}
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(407.0, 100.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return formatMatrix;
}


- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource
{
	currentSettings = (MacOSaiXBitmapExportSettings *)dataSource;
	
	[self refresh];
}


- (IBAction)setFormat:(id)sender
{
	NSString	*previousValue = [[[currentSettings format] retain] autorelease];
	
	if ([formatMatrix selectedRow] == 0)
		[currentSettings setFormat:@"JPEG"];
	else if ([formatMatrix selectedRow] == 1)
		[currentSettings setFormat:@"JPEG 2000"];
	else if ([formatMatrix selectedRow] == 2)
		[currentSettings setFormat:@"PNG"];
	else if ([formatMatrix selectedRow] == 3)
		[currentSettings setFormat:@"TIFF"];
	
	[[self delegate] dataSource:currentSettings 
				   didChangeKey:@"format" 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Change Format", @"")];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	targetImageSize = [[currentSettings targetImage] size];
	float	aspectRatio = targetImageSize.width / targetImageSize.height;
	
	if ([notification object] == widthField)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		float	newWidth = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newHeight = newWidth / aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setHeight:newHeight];
		[heightField setFloatValue:newHeight];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthAndHeight" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Width", @"")];
	}
	else if ([notification object] == heightField)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		float	newHeight = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] string] floatValue], 
				newWidth = newHeight * aspectRatio;
		
		[currentSettings setWidth:newWidth];
		[currentSettings setHeight:newHeight];
		[widthField setFloatValue:newWidth];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthAndHeight" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Height", @"")];
	}
}


- (float)conversionFactorFrom:(MacOSaiXBitmapUnits)fromUnits to:(MacOSaiXBitmapUnits)toUnits
{
	float factor = 1.0;
	
	if (fromUnits == pixelUnits && toUnits == inchUnits)
		factor = 1.0 / [currentSettings pixelsPerInch];
	else if (fromUnits == pixelUnits && toUnits == cmUnits)
		factor = 2.54 / [currentSettings pixelsPerInch];
	else if (fromUnits == inchUnits && toUnits == pixelUnits)
		factor = [currentSettings pixelsPerInch];
	else if (fromUnits == inchUnits && toUnits == cmUnits)
		factor = 2.54;
	else if (fromUnits == cmUnits && toUnits == pixelUnits)
		factor = [currentSettings pixelsPerInch] / 2.54;
	else if (fromUnits == cmUnits && toUnits == inchUnits)
		factor = 1.0 / 2.54;

	return factor;
}


- (IBAction)setUnits:(id)sender
{
	MacOSaiXBitmapUnits	currentUnits = [currentSettings units], 
						newUnits = [unitsPopUp selectedTag];
	
	if (newUnits != currentUnits)
	{
		NSArray	*previousValue = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[currentSettings width]], [NSNumber numberWithFloat:[currentSettings height]], [NSNumber numberWithInt:[currentSettings units]], nil];
		
			// Show fractional parts of the width and height for units except pixels.
		NSString	*floatFormat = @"#,##0.0##; 0.0", 
					*integerFormat = @"#,##0; 0";
		[[widthField formatter] setFormat:(newUnits == pixelUnits ? integerFormat : floatFormat)];
		[[heightField formatter] setFormat:(newUnits == pixelUnits ? integerFormat : floatFormat)];

			// Convert the width and height values to the new units.
		float		factor = [self conversionFactorFrom:currentUnits to:newUnits], 
					newWidth = [currentSettings width] * factor, 
					newHeight = [currentSettings height] * factor;
		[currentSettings setWidth:newWidth];
		[widthField setFloatValue:newWidth];
		[currentSettings setHeight:newHeight];
		[heightField setFloatValue:newHeight];
		
		[currentSettings setUnits:newUnits];
		
		[[self delegate] dataSource:currentSettings 
					   didChangeKey:@"widthHeightUnits" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Units", @"")];
	}
}


- (IBAction)setResolution:(id)sender
{
	int	previousValue = [currentSettings pixelsPerInch];
	
	[currentSettings setPixelsPerInch:[resolutionPopUp selectedTag]];
	
	[[self delegate] dataSource:currentSettings 
				   didChangeKey:@"pixelsPerInch" 
					  fromValue:[NSNumber numberWithInt:previousValue] 
					 actionName:NSLocalizedString(@"Change Resolution", @"")];
}


- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	return NO;
}


- (void)refresh
{
	if ([[currentSettings format] isEqualToString:@"JPEG"])
		[formatMatrix selectCellAtRow:0 column:0];
	else if ([[currentSettings format] isEqualToString:@"JPEG 2000"])
		[formatMatrix selectCellAtRow:1 column:0];
	else if ([[currentSettings format] isEqualToString:@"PNG"])
		[formatMatrix selectCellAtRow:2 column:0];
	else if ([[currentSettings format] isEqualToString:@"TIFF"])
		[formatMatrix selectCellAtRow:3 column:0];
	
	[widthField setFloatValue:[currentSettings width]];
	[heightField setFloatValue:[currentSettings height]];
	
	[unitsPopUp selectItemWithTag:[currentSettings units]];
	
	[resolutionPopUp selectItemWithTag:[currentSettings pixelsPerInch]];
	
	[self setUnits:self];
}


- (void)editingDidComplete
{
	[currentSettings setWidth:[widthField floatValue]];
	[currentSettings setHeight:[heightField floatValue]];

	currentSettings = nil;
}


@end
