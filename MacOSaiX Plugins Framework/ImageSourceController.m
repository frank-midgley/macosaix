#import "ImageSourceController.h"
#import "ImageSource.h"
#import "MacOSaiXDocument.h"


@implementation ImageSourceController


- (void)setDocument:(NSDocument *)document
{
	_document = document;
}


- (void)createNewImageSourceForWindow:(NSWindow *)window
{
}


- (void)addImageSource:(ImageSource *)imageSource
{
	[(MacOSaiXDocument *)_document addImageSource:imageSource];
}


- (BOOL)canHaveMultipleImageSources
{
	return YES;
}


- (void)createNewImageSource
{
}


- (void)editImageSource:(ImageSource *)imageSource
{
}


@end
