//
//  MacOSaiXWebPageExporterPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWebPageExporterPlugIn.h"

#import "MacOSaiXWebPageExportEditor.h"
#import "MacOSaiXWebPageExporter.h"
#import "MacOSaiXWebPageExportSettings.h"


@implementation MacOSaiXWebPageExporterPlugIn


+ (NSImage *)image
{
	return nil;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXWebPageExportSettings class];
}


+ (Class)editorClass
{
	return [MacOSaiXWebPageExportEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


+ (Class)exporterClass
{
	return [MacOSaiXWebPageExporter class];
}


@end
