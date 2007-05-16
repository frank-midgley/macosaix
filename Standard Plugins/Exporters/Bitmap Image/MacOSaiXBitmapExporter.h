//
//  MacOSaiXBitmapExporter.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXBitmapExportSettings;


@interface MacOSaiXBitmapExporter : NSObject <MacOSaiXExporter>
{
	MacOSaiXBitmapExportSettings	*exportSettings;
	NSURL							*exportURL;
	unsigned char					*bitmapBuffer;
	CGColorSpaceRef					cgColorSpace;
	CGContextRef					cgContext;
	CGImageDestinationRef			cgImageDest;
}

@end
