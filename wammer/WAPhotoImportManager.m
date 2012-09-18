//
//  WAPhotoImportManager.m
//  wammer
//
//  Created by kchiu on 12/9/11.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAPhotoImportManager.h"
#import "WADataStore.h"
#import "WAArticle.h"
#import "WAAssetsLibraryManager.h"
#import "WAFile+ThumbnailMaker.h"
#import <AssetsLibrary+IRAdditions.h>
#import "GANTracker.h"

@interface WAPhotoImportManager ()

@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation WAPhotoImportManager

+ (WAPhotoImportManager *) defaultManager {
	
	static WAPhotoImportManager *returnedManager = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		
		returnedManager = [[self alloc] init];
    
	});
	
	return returnedManager;
	
}

- (NSManagedObjectContext *)managedObjectContext {

	if (_managedObjectContext) {
		_managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	}
	return _managedObjectContext;

}

- (WAArticle *)lastImportedArticle {

	if (!_lastImportedArticle) {
		_lastImportedArticle = [[WADataStore defaultStore] fetchLatestLocalImportedArticleUsingContext:self.managedObjectContext];
	}
	return _lastImportedArticle;

}

- (void)createPhotoImportArticlesWithCompletionBlock:(WAPhotoImportCallback)aCallbackBlock {

	if (!self.finished) {
		return;
	}

	self.finished = NO;
	self.canceled = NO;

	NSManagedObjectContext *context = self.managedObjectContext;
	__weak WAPhotoImportManager *wSelf = self;

	[context performBlock:^{

		[[WAAssetsLibraryManager defaultManager] enumerateSavedPhotosSince:wSelf.lastImportedArticle.creationDate onProgess:^(NSArray *assets) {

			if (![assets count]) {
				return wSelf.canceled;
			}

			WAArticle *article = [WAArticle objectInsertingIntoContext:context withRemoteDictionary:[NSDictionary dictionary]];
			[assets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

				@autoreleasepool {

					WAFile *file = (WAFile *)[WAFile objectInsertingIntoContext:article.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
					
					NSError *error = nil;
					if (![file.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObjects:file, article, nil] error:&error])
						NSLog(@"Error obtaining permanent object ID: %@", error);
					
					[[article mutableOrderedSetValueForKey:@"files"] addObject:file];
					
					WAThumbnailMakeOptions options = 0;
					if (idx < 4) {
						options |= WAThumbnailMakeOptionMedium;
					}
					if (idx < 3) {
						options |= WAThumbnailMakeOptionSmall;
					}
					
					ALAsset *asset = (ALAsset *)obj;
					[file makeThumbnailsWithImage:[[asset defaultRepresentation] irImage] options:options];
					
					UIImage *extraSmallThumbnailImage = [UIImage imageWithCGImage:[asset thumbnail]];
					file.extraSmallThumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:UIImageJPEGRepresentation(extraSmallThumbnailImage, 0.85f) extension:@"jpeg"] path];
					
					file.assetURL = [[[asset defaultRepresentation] url] absoluteString];
					file.resourceType = (NSString *)kUTTypeImage;
					file.timestamp = [asset valueForProperty:ALAssetPropertyDate];
					
					if (!article.creationDate) {
						article.creationDate = file.timestamp;
					} else {
						if ([file.timestamp compare:article.creationDate] == NSOrderedDescending) {
							article.creationDate = file.timestamp;
						}
					}

				}

			}];

			article.import = [NSNumber numberWithInt:WAImportTypeFromLocal];
			article.draft = (id)kCFBooleanFalse;
			CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
			if (theUUID)
				article.identifier = [((__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theUUID)) lowercaseString];
			CFRelease(theUUID);
			article.dirty = (id)kCFBooleanTrue;
			article.creationDeviceName = [UIDevice currentDevice].name;
			
			NSError *savingError = nil;
			if ([context save:&savingError]) {
				[[GANTracker sharedTracker] trackEvent:@"CreatePost"
																				action:@"CameraRoll"
																				 label:@"Photos"
																				 value:[article.files count]
																		 withError:NULL];
				wSelf.lastImportedArticle = article;
			} else {
				NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, savingError);
			}
			
			return wSelf.canceled;

		} onComplete:^{
			
			wSelf.finished = YES;
			if (wSelf.canceled) {
				wSelf.managedObjectContext = nil;
				wSelf.lastImportedArticle = nil;
			}
			aCallbackBlock();
			
		} onFailure:^(NSError *error) {
			
			NSLog(@"Unable to enumerate saved photos: %s %@", __PRETTY_FUNCTION__, error);

		}];

	}];
	
}

@end
