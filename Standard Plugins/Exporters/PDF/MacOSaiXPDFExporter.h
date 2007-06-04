//
//  MacOSaiXPDFExporter.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXPDFExportSettings;


@interface MacOSaiXPDFExporter : NSObject <MacOSaiXExporter>
{
	MacOSaiXPDFExportSettings	*exportSettings;
	
	NSFileHandle				*exportFileHandle;
	unsigned long				objectCount, 
								rootID, 
								contentsID, 
								xObjectsID;
	NSMutableString				*contentStream;
	NSMutableArray				*objectOffsets;
	NSMutableDictionary			*imageIDs;
}

@end


@interface NSBezierPath (MacOSaiXPDFExporter)
- (NSString *)pdfPath;
@end


@interface NSBitmapImageRep (MacOSaiXPDFExporter)
- (NSString *)pdfASCII85Stream;
@end


@interface NSString (MacOSaiXPDFExporter)
+ (NSString *)stringWithFloat:(float)floatValue;
@end
