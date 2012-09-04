//
//  WACompositionViewController+ImageHandling.m
//  wammer
//
//  Created by Evadne Wu on 2/21/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WACompositionViewController+ImageHandling.h"
#import "UIKit+IRAdditions.h"
#import "AssetsLibrary+IRAdditions.h"
#import "WADataStore.h"
#import "WADefines.h"

#import <objc/runtime.h>
#import "WACompositionViewController+SubclassEyesOnly.h"
#import "IRAQPhotoPickerController.h"
#import "WAAssetsLibraryManager.h"

NSString * const WACompositionImageInsertionUsesCamera = @"WACompositionImageInsertionUsesCamera";
NSString * const WACompositionImageInsertionAnimatePresentation = @"WACompositionImageInsertionAnimatePresentation";
NSString * const WACompositionImageInsertionCancellationTriggersSessionTermination = @"WACompositionImageInsertionCancellationTriggersSessionTermination";

NSString * const kDismissesSelfIfCameraCancelled = @"-[WACompositionViewController(ImageHandling) dismissesSelfIfCameraCancelled]";

@interface WACompositionViewController (ImageHandling_Private)

- (IRAction *) newPresentImagePickerControllerActionAnimated:(BOOL)animate sender:(id)sender;
- (IRAction *) newPresentCameraCaptureControllerActionAnimated:(BOOL)animate sender:(id)sender;

@end


@implementation WACompositionViewController (ImageHandling)

+ (ALAssetsLibrary *) defaultAssetsLibrary {
	static dispatch_once_t onceToken = 0;
	static ALAssetsLibrary *library = nil;
	dispatch_once(&onceToken, ^{
		library = [[ALAssetsLibrary alloc] init];
	});
	return library;
}

- (IRAction *) newPresentImagePickerControllerActionAnimated:(BOOL)animate sender:(id)sender {

	ALAssetsLibrary *assetsLibrary = [WACompositionViewController defaultAssetsLibrary];
	__weak WACompositionViewController *wSelf = self;
	__block IRAQPhotoPickerController *imagePickerController = [[IRAQPhotoPickerController alloc] initWithAssetsLibrary:assetsLibrary completion:^(NSArray *selectedAssets, NSError *error) {
		if (!error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[wSelf.managedObjectContext save:nil];
				[wSelf handleSelectionWithArray:selectedAssets];
				[wSelf dismissImagePickerController:imagePickerController animated:YES];
				imagePickerController = nil;
				
			});
						
		} else if ([[error domain] isEqualToString:ALAssetsLibraryErrorDomain] && error.code == ALAssetsLibraryAccessUserDeniedError) {
			
			NSCParameterAssert(![NSThread isMainThread]);
			
			dispatch_async(dispatch_get_main_queue(), ^{

				NSCParameterAssert([NSThread isMainThread]);
				
				NSString *title = NSLocalizedString(@"TURN_ON_LOCATION_SERVICE", @"Alert on no location service enabled when open photo library");
				IRAction *okayAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_OKAY", nil) block:^{
					
					[wSelf dismissImagePickerController:imagePickerController animated:YES];
					imagePickerController = nil;
					
				}];
				
				[[IRAlertView alertViewWithTitle:nil message:title cancelAction:nil otherActions:[NSArray arrayWithObjects:okayAction, nil]] show];

			});
			
		}

	}];
	
	return [IRAction actionWithTitle:NSLocalizedString(@"ACTION_INSERT_PHOTO_FROM_LIBRARY", @"Button title for showing an image picker") block: ^ {
	
		[wSelf presentImagePickerController:imagePickerController sender:sender animated:YES];
	
	}];

}

- (void) presentImagePickerController:(UIViewController *)controller sender:(id)sender animated:(BOOL)animated {

	NSParameterAssert(controller);

	__block UIViewController * (^topNonModalVC)(UIViewController *) = [^ (UIViewController *aVC) {
		
		if (aVC.modalViewController)
			return topNonModalVC(aVC.modalViewController);
		
		return aVC;
		
	} copy];
	
	[topNonModalVC(self) presentModalViewController:controller animated:animated];
	
	topNonModalVC = nil;

}

- (void) dismissImagePickerController:(UIViewController *)controller animated:(BOOL)animated {

	[controller dismissModalViewControllerAnimated:animated];

}

- (IRAction *) newPresentCameraCaptureControllerActionAnimated:(BOOL)animate sender:(id)sender {

	if (![IRImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear])
		return nil;
	
	__weak WACompositionViewController *wSelf = self;
	__weak id wSender = sender;
	
	return [IRAction actionWithTitle:NSLocalizedString(@"ACTION_TAKE_PHOTO_WITH_CAMERA", @"Button title for showing a camera capture controller") block: ^ {
	
		[wSelf presentCameraCapturePickerController:[wSelf newCameraCapturePickerController] sender:wSender animated:animate];
	
	}];

}

- (IRImagePickerController *) newCameraCapturePickerController {

	__weak WACompositionViewController *wSelf = self;
	
	__block IRImagePickerController *nrPickerController = [IRImagePickerController cameraImageCapturePickerWithAssetsLibrary:[[WAAssetsLibraryManager defaultManager] assetsLibrary] completionBlock:^(ALAsset *representedAsset) {
		
		[wSelf.managedObjectContext save:nil];

		WAThumbnailMakeOptions options = WAThumbnailMakeOptionExtraSmall;
		if ([self.article.files count] == 0) {
			options |= WAThumbnailMakeOptionMedium;
		}
		if ([self.article.files count] < 3) {
			options |= WAThumbnailMakeOptionSmall;
		}
		[wSelf handleIncomingSelectedAsset:representedAsset options:options];

		[wSelf dismissCameraCapturePickerController:nrPickerController animated:YES];
		
		nrPickerController = nil;
		
	}];
	
	return nrPickerController;

}

- (void) presentCameraCapturePickerController:(UIViewController *)controller sender:(id)sender animated:(BOOL)animated {

	__block UIViewController * (^topNonModalVC)(UIViewController *) = [^ (UIViewController *aVC) {
		
		if (aVC.modalViewController)
			return topNonModalVC(aVC.modalViewController);
		
		return aVC;
		
	} copy];
	
	[topNonModalVC(self) presentModalViewController:controller animated:animated];
	
	topNonModalVC = nil;

}

- (void) dismissCameraCapturePickerController:(UIViewController *)controller animated:(BOOL)animated {

	[controller dismissModalViewControllerAnimated:animated];

}

- (void) handleSelectionWithArray: (NSArray *)selectedAssets {
	
	[selectedAssets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		ALAsset *asset = obj;
		WAThumbnailMakeOptions options = WAThumbnailMakeOptionExtraSmall;
		if (idx == 0) {
			options |= WAThumbnailMakeOptionMedium;
		}
		if (idx < 3) {
			options |= WAThumbnailMakeOptionSmall;
		}
		[self handleIncomingSelectedAsset:asset options:options];
	}];
		
}

- (void) makeAssociatedImagesOfFile:(WAFile *)file withRepresentedAsset:(ALAsset *)representedAsset options:(WAThumbnailMakeOptions)options {

	NSParameterAssert(representedAsset);

	__weak WACompositionViewController *wSelf = self;
	
	[self.managedObjectContext performBlock:^{
		
		WADataStore *ds = [WADataStore defaultStore];

		if (options & WAThumbnailMakeOptionSmall || options & WAThumbnailMakeOptionMedium) {

			UIImage *image = [[representedAsset defaultRepresentation] irImage];
			CGSize imageSize = image.size;
			UIImage *standardImage = [image irStandardImage];
			
			if (options & WAThumbnailMakeOptionSmall) {
				CGFloat const smallSideLength = kWAFileSmallImageSideLength;
				
				if ((imageSize.width > smallSideLength) || (imageSize.height > smallSideLength)) {
					
					UIImage *smallThumbnailImage = [standardImage irScaledImageWithSize:IRGravitize((CGRect){ CGPointZero, (CGSize){ smallSideLength, smallSideLength } }, image.size, kCAGravityResizeAspect).size];
					
					file.smallThumbnailFilePath = [[ds persistentFileURLForData:UIImageJPEGRepresentation(smallThumbnailImage, 0.85f) extension:@"jpeg"] path];
					
				} else {
					
					file.smallThumbnailFilePath = [[ds persistentFileURLForData:UIImageJPEGRepresentation(standardImage, 0.85f) extension:@"jpeg"] path];
					
				}
			}
			
			if (options & WAThumbnailMakeOptionMedium) {
				CGFloat const mediumSideLength = kWAFileMediumImageSideLength;
				
				if ((imageSize.width > mediumSideLength) || (imageSize.height > mediumSideLength)) {
					
					UIImage *thumbnailImage = [standardImage irScaledImageWithSize:IRGravitize((CGRect){ CGPointZero, (CGSize){ mediumSideLength, mediumSideLength } }, image.size, kCAGravityResizeAspect).size];
					
					file.thumbnailFilePath = [[ds persistentFileURLForData:UIImageJPEGRepresentation(thumbnailImage, 0.85f) extension:@"jpeg"] path];
					
				} else {
					
					file.thumbnailFilePath = [[ds persistentFileURLForData:UIImageJPEGRepresentation(standardImage, 0.85f) extension:@"jpeg"] path];
					
				}
			}
		}
		
		if (options & WAThumbnailMakeOptionExtraSmall) {
			
			UIImage *extraSmallThumbnailImage = [UIImage imageWithCGImage:[representedAsset aspectRatioThumbnail]];
			file.extraSmallThumbnailFilePath = [[ds persistentFileURLForData:UIImageJPEGRepresentation(extraSmallThumbnailImage, 1.0f) extension:@"jpeg"] path];
			
		}
		
		NSError *savingError = nil;
		if (![wSelf.managedObjectContext save:&savingError])
			NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, savingError);
		
	}];

}

- (void) handleIncomingSelectedAsset:(ALAsset *)representedAsset options:(WAThumbnailMakeOptions)options {

	if (representedAsset) {
		
		NSManagedObjectContext *context = self.managedObjectContext;
		NSManagedObjectID *articleID = [self.article objectID];
		NSCParameterAssert(![articleID isTemporaryID]);
		
		NSURL *articleURI = [articleID URIRepresentation];
		__weak WACompositionViewController* wSelf = self;
		
		[context performBlock:^{
		
			WAArticle *article = (WAArticle *)[context irManagedObjectForURI:articleURI];
			NSCParameterAssert(article);
						
			WAFile *file = (WAFile *)[WAFile objectInsertingIntoContext:article.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
			
			NSError *error = nil;
			if (![file.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObjects:file, article, nil] error:&error])
				NSLog(@"Error obtaining permanent object ID: %@", error);

			[article willChangeValueForKey:@"files"];
			[[article mutableOrderedSetValueForKey:@"files"] addObject:file];
			[article didChangeValueForKey:@"files"];
						
			[wSelf makeAssociatedImagesOfFile:file withRepresentedAsset:representedAsset options:options];

			file.assetURL = [[[representedAsset defaultRepresentation] url] absoluteString];
			file.resourceType = (NSString *)kUTTypeImage;

			NSError *savingError = nil;
			if (![context save:&savingError])
				NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, savingError);
			
		}];
		
	} else {
		
		//	If told to dismiss self, dismiss here if self has no changess
		
		BOOL shouldDismissSelfOnCameraCancellation = [objc_getAssociatedObject(self, &kDismissesSelfIfCameraCancelled) isEqual:(id)kCFBooleanTrue];
		
		if (shouldDismissSelfOnCameraCancellation) {
			
			if (![self.article hasMeaningfulContent]) {
 
				self.completionBlock(nil);

			}
			
		}
		
	}
	
	objc_setAssociatedObject(self, &kDismissesSelfIfCameraCancelled, nil, OBJC_ASSOCIATION_ASSIGN);

}

- (BOOL) shouldDismissSelfOnCameraCancellation {
	
	return [objc_getAssociatedObject(self, &kDismissesSelfIfCameraCancelled) isEqual:(id)kCFBooleanTrue];

}

- (void) handleImageAttachmentInsertionRequestWithSender:(id)sender {

	[self handleImageAttachmentInsertionRequestWithOptions:nil sender:sender];

}

- (void) handleImageAttachmentInsertionRequestWithOptions:(NSDictionary *)options sender:(id)sender {
		
	NSMutableArray *availableActions = [NSMutableArray array];
	
	BOOL usesCamera = [[options objectForKey:WACompositionImageInsertionUsesCamera] isEqual:(id)kCFBooleanTrue];
	BOOL animate = ![[options objectForKey:WACompositionImageInsertionAnimatePresentation] isEqual:(id)kCFBooleanFalse];
	BOOL dismissesSelfIfCameraCancelled = [[options objectForKey:WACompositionImageInsertionCancellationTriggersSessionTermination] isEqual:(id)kCFBooleanTrue];
	
	objc_setAssociatedObject(self, &kDismissesSelfIfCameraCancelled, (dismissesSelfIfCameraCancelled ? (id)kCFBooleanTrue : (id)kCFBooleanFalse), OBJC_ASSOCIATION_ASSIGN);
	
	IRAction *cameraAction = [self newPresentCameraCaptureControllerActionAnimated:animate sender:sender];
	
	if (cameraAction)
		[availableActions addObject:cameraAction];
	
	if (usesCamera && cameraAction) {
	
		[cameraAction invoke];
	
	} else {
		
		IRAction *photoPickerAction = [self newPresentImagePickerControllerActionAnimated:animate sender:sender];
		[availableActions addObject:photoPickerAction];

		if (usesCamera && photoPickerAction) {
	
			[photoPickerAction invoke];
		
		} else if ([availableActions count] == 1) {
			
			//	With only one action we don’t even need to show the action sheet
			
			dispatch_async(dispatch_get_main_queue(), ^ {
				[(IRAction *)[availableActions objectAtIndex:0] invoke];
			});
			
		} else {
		
			IRActionSheetController *controller = [IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:nil otherActions:availableActions];
			IRActionSheet *actionSheet = (IRActionSheet *)[controller singleUseActionSheet];
			
			if ([sender isKindOfClass:[UIView class]]) {
				
				[actionSheet showFromRect:((UIView *)sender).bounds inView:((UIView *)sender) animated:YES];
				
			} else if ([sender isKindOfClass:[UIBarButtonItem class]]) {
				
				[actionSheet showFromBarButtonItem:((UIBarButtonItem *)sender) animated:YES];
				
			} else {
				
				[NSException raise:NSInternalInconsistencyException format:@"Sender %@ is neither a view or a bar button item.  Don’t know what to do.", sender];
			
			}
			
		}
	}
	
}

@end
