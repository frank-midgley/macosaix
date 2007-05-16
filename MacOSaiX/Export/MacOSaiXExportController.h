//
//  MacOSaiXExportController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"

@class MacOSaiXMosaic, MacOSaiXProgressController;
@protocol MacOSaiXExportSettings, MacOSaiXExporterEditor;


@interface MacOSaiXExportController : NSObject <MacOSaiXEditorDelegate>
{
//	IBOutlet NSButton			*includeTargetButton;
//	
//	IBOutlet NSButton			*openWhenCompleteButton;
	
	NSSavePanel						*savePanel;
	
	IBOutlet NSView					*sharedView;
	IBOutlet NSPopUpButton			*formatPopUp;
	
	MacOSaiXMosaic					*mosaic;
	id								delegate;
	SEL								didEndSelector;
	
	MacOSaiXProgressController		*progressController;
	
	id<MacOSaiXExportSettings>		exportSettings;
	id<MacOSaiXDataSourceEditor>	exporterEditor;
	
//	BOOL						createWebPage, 
//								includeTargetImage, 
//								openWhenComplete, 
	BOOL							exportWasCancelled;
}

- (void)exportMosaic:(MacOSaiXMosaic *)mosaic
			withName:(NSString *)name 
	  modalForWindow:(NSWindow *)window 
	   modalDelegate:(id)inDelegate
	  didEndSelector:(SEL)inDidEndSelector;

- (IBAction)setFormat:(id)sender;

//- (IBAction)setImageFormat:(id)sender;
//- (IBAction)setCreateWebPage:(id)sender;
//- (IBAction)setIncludeTargetImage:(id)sender;
//
//- (IBAction)setOpenImageWhenComplete:(id)sender;

- (IBAction)cancelExport:(id)sender;

//- (NSString *)exportFormat;

@end
