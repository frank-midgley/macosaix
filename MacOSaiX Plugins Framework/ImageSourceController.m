#import "ImageSourceController.h"
#import "ImageSource.h"
#import "MacOSaiXDocument.h"


@implementation ImageSourceController


+ (NSString *)name
{
	return @"";
}


- (NSView *)imageSourceView
{
	return nil;
}


- (void)addImageSource:(id)sender
{
}


- (void)cancelAddImageSource:(id)sender
{
	[self showCurrentImageSources];
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


- (void)showCurrentImageSources
{
	[[self document] showCurrentImageSources];
}


@end
