//
//  MacOSaiXGoogleKioskController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXGoogleKioskController.h"

#import "GoogleImageSource.h"


@implementation MacOSaiXGoogleKioskController


- (NSString *)windowNibName
{
	return @"Google Kiosk";
}


- (void)awakeFromNib
{
	NSString		*kioskPath = @"/Users/frank/Desktop/Google Kiosk";
	NSArray			*kioskItems = [[NSFileManager defaultManager] directoryContentsAtPath:kioskPath];
	kioskItems = [kioskItems sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

		// Populate the images
	NSEnumerator	*itemEnumerator = [kioskItems objectEnumerator];
	NSString		*item = nil;
	int				imageCount = 0;
	while (item = [itemEnumerator nextObject])
	{
		NSImage	*originalImage = [[NSImage alloc] initWithContentsOfFile:[kioskPath stringByAppendingPathComponent:item]];
		if (originalImage)
		{
			[originalImage setScalesWhenResized:YES];
			[originalImage setSize:NSMakeSize(100.0, 100.0)];
			[[originalImageMatrix cellAtRow:(int)(imageCount / 3.0) column:imageCount % 3] setImage:originalImage];
			[originalImage release];
			imageCount++;
		}
	}
	
		// Populate the keywords
	NSString		*keywords = [NSString stringWithContentsOfFile:[kioskPath stringByAppendingPathComponent:@"Keywords.txt"]];
	NSArray			*keywordsArray = [keywords componentsSeparatedByString:@"\n"];
	keywordsArray = [keywordsArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	int				row = 0, 
					column = 0, 
					rowCount = [keywordMatrix numberOfRows], 
					columnCount = [keywordMatrix numberOfColumns];
		
	for (column = 0; column < columnCount; column++)
		for (row = 0; row < rowCount; row++)
		{
			int				index = column * rowCount + row;
			NSButtonCell	*buttonCell = [keywordMatrix cellAtRow:row column:column];
			if (index < [keywordsArray count])
			{
				NSString		*keyword = [keywordsArray objectAtIndex:index];
				
					// Create an image source for this keyword.
				GoogleImageSource	*imageSource = [[GoogleImageSource alloc] init];
				[imageSource setAdultContentFiltering:strictFiltering];
				[imageSource setRequiredTerms:keyword];
				[imageSources setObject:imageSource forKey:keyword];
				[imageSource release];
				
					// Add the keyword to the matrix
				[buttonCell setTitle:keyword];
			}
			else
			{
				[buttonCell setTitle:@""];
				[buttonCell setEnabled:NO];
			}
		}
}


- (IBAction)setOriginalImage:(id)sender
{
}


- (IBAction)toggleKeyword:(id)sender
{
	
}


@end
