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
	NSSavePanel						*savePanel;
	
	IBOutlet NSView					*sharedView;
	IBOutlet NSPopUpButton			*formatPopUp;
	IBOutlet NSButton				*openWhenCompletedButton;
	
	MacOSaiXMosaic					*mosaic;
	float							targetImageOpacity;
	id								delegate;
	SEL								didEndSelector;
	
	MacOSaiXProgressController		*progressController;
	
	id<MacOSaiXExportSettings>		exportSettings;
	id<MacOSaiXDataSourceEditor>	exporterEditor;
	
	BOOL							openWhenCompleted, 
									exportWasCancelled;
}

- (void)exportMosaic:(MacOSaiXMosaic *)mosaic
			withName:(NSString *)name 
  targetImageOpacity:(float)opacity
	  modalForWindow:(NSWindow *)window 
	   modalDelegate:(id)inDelegate
	  didEndSelector:(SEL)inDidEndSelector;

- (IBAction)setFormat:(id)sender;

- (IBAction)setOpenWhenCompleted:(id)sender;

- (IBAction)cancelExport:(id)sender;

@end
