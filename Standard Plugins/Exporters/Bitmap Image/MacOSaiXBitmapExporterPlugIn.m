//
//  MacOSaiXBitmapExporterPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXBitmapExporterPlugIn.h"

#import "MacOSaiXBitmapExportEditor.h"
#import "MacOSaiXBitmapExporter.h"
#import "MacOSaiXBitmapExportSettings.h"


@implementation MacOSaiXBitmapExporterPlugIn


+ (NSImage *)image
{
	static NSImage	*image = nil;
	
	if (!image)
		image = [[[NSWorkspace sharedWorkspace] iconForFileType:@"png"] retain];
	
	return image;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXBitmapExportSettings class];
}


+ (Class)editorClass
{
	return [MacOSaiXBitmapExportEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


+ (Class)exporterClass
{
	return [MacOSaiXBitmapExporter class];
}


@end
