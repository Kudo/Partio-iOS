//
//  WAAssetsLibraryManager.m
//  wammer
//
//  Created by kchiu on 12/9/3.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAAssetsLibraryManager.h"

@interface NSDate (WAAssetsLibraryManager)

- (NSDate *)laterMidnight;

@end

@implementation NSDate (WAAssetsLibraryManager)

- (NSDate *)laterMidnight {

	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *components = [gregorian components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:self];
	const NSTimeInterval dayTimeInterval = 24 * 60 * 60;
	return [[gregorian dateFromComponents:components] dateByAddingTimeInterval:dayTimeInterval];

}

@end


@implementation WAAssetsLibraryManager

+ (WAAssetsLibraryManager *) defaultManager {
	
	static WAAssetsLibraryManager *returnedManager = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		
		returnedManager = [[self alloc] init];
    
	});
	
	return returnedManager;

}

- (id)init {

	self = [super init];

	if (self) {

		self.assetsLibrary = [[ALAssetsLibrary alloc] init];

	}

	return self;

}

- (void)assetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock {

	[self.assetsLibrary assetForURL:assetURL resultBlock:resultBlock failureBlock:failureBlock];

}

- (void)writeImageToSavedPhotosAlbum:(CGImageRef)imageRef orientation:(ALAssetOrientation)orientation completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock {

	[self.assetsLibrary writeImageToSavedPhotosAlbum:imageRef orientation:orientation completionBlock:completionBlock];

}

- (void)enumerateSavedPhotosSince:(NSDate *)sinceDate onProgess:(BOOL (^)(NSArray *))onProgressBlock onComplete:(void (^)())onCompleteBlock onFailure:(void (^)(NSError *))onFailureBlock {

	__block NSMutableArray *insertedAssets = [[NSMutableArray alloc] init];
	__block NSDate *midnight = sinceDate ? [sinceDate laterMidnight] : nil;

	[self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
		
		if (group) {

			[group setAssetsFilter:[ALAssetsFilter allPhotos]];
			[group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {

				BOOL isCanceled = NO;

				if (result) {

					NSDate *assetDate = [result valueForProperty:ALAssetPropertyDate];

					if (sinceDate && ([assetDate compare:sinceDate] != NSOrderedDescending)) {
						return;
					}
					
					if (midnight) {
						
						if ([assetDate compare:midnight] != NSOrderedAscending) {
							
							isCanceled = onProgressBlock(insertedAssets);
							[insertedAssets removeAllObjects];
							midnight = [assetDate laterMidnight];
							
						}
						
					} else {
						
						midnight = [assetDate laterMidnight];
						
					}
					
					[insertedAssets addObject:result];

				} else {

					isCanceled = onProgressBlock(insertedAssets);
					
				}

				if (isCanceled) {
					*stop = YES;
				}

			}];

		} else {

			onCompleteBlock();

		}

	} failureBlock:^(NSError *error) {

		onFailureBlock(error);

	}];

}

@end