/*
 *  MacOSaiXExporter.h
 *  MacOSaiX
 *
 *  Created by Frank Midgley on 5/8/07.
 *  Copyright 2007 Frank M. Midgley. All rights reserved.
 *
 */

#import "MacOSaiXPlugIn.h"

@protocol MacOSaiXImageSource;


@protocol MacOSaiXExporterPlugIn <MacOSaiXPlugIn>

+ (Class)exporterClass;

@end


@protocol MacOSaiXExportSettings <MacOSaiXDataSource>

- (void)setTargetImage:(NSImage *)image;

- (NSImage *)targetImage;

- (NSString *)exportFormat;

- (NSString *)exportExtension;

@end


@protocol MacOSaiXExporter <NSObject>

- (id)createFileAtURL:(NSURL *)exportURL 
		 withSettings:(id<MacOSaiXExportSettings>)exportSettings;

- (id)fillTileWithColor:(NSColor *)fillColor 
		  clippedToPath:(NSBezierPath *)clipPath;

- (id)fillTileWithImage:(NSImage *)image 
		 withIdentifier:(NSString *)imageIdentifier 
			 fromSource:(id<MacOSaiXImageSource>)imageSource 
		centeredAtPoint:(NSPoint)centerPoint 
			   rotation:(float)imageRotation 
		  clippedToPath:(NSBezierPath *)clipPath 
				opacity:(float)opacity;

- (id)closeFile;

- (id)openFileInExternalViewer:(NSURL *)exportURL;

@end
