//
//  MacOSaiXWebPageExporter.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXWebPageExportSettings;


@interface MacOSaiXWebPageExporter : NSObject <MacOSaiXExporter>
{
	MacOSaiXWebPageExportSettings	*exportSettings;
	NSURL							*exportURL;
	unsigned char					*bitmapBuffer;
	CGColorSpaceRef					cgColorSpace;
	CGContextRef					cgContext;
	CGImageDestinationRef			cgImageDest;
	
	NSMutableString					*tilesHTML, 
									*areasHTML;
	NSMutableDictionary				*thumbnailNumbers;
	int								thumbnailCount;
}

@end
