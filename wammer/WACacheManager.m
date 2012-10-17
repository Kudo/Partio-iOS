//
//  WACacheManager.m
//  wammer
//
//  Created by kchiu on 12/10/8.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WACacheManager.h"
#import "WADataStore.h"

NSString * const kWACacheConstructionFinished = @"WACacheConstructionFinished";

@interface WACacheManager ()

@property (nonatomic, readwrite, assign) BOOL constructionFinished;

+ (NSString *)archivePath;

- (void)handleApplicationDidEnterBackground:(NSNotification *)note;
- (void)initCacheEntities;

@end

@implementation WACacheManager

+ (WACacheManager *)sharedManager {

	static WACacheManager *returnedManager = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		
		returnedManager = [NSKeyedUnarchiver unarchiveObjectWithFile:[[self class] archivePath]];
		if (!returnedManager) {
			returnedManager = [[self alloc] init];
		}
    
	});
	
	return returnedManager;

}

- (id)init {

	self = [super init];
	if (self) {
		[self setConstructionFinished:NO];
		[self initCacheEntities];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	return self;

}

- (id)initWithCoder:(NSCoder *)aDecoder {

	self = [super init];
	if (self) {
		[self setConstructionFinished:[aDecoder decodeBoolForKey:kWACacheConstructionFinished]];
		if (![self constructionFinished]) {
			[self initCacheEntities];
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	return self;

}

- (void)encodeWithCoder:(NSCoder *)aCoder {

	[aCoder encodeBool:[self constructionFinished] forKey:kWACacheConstructionFinished];

}

- (void)dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];

}

- (void)handleApplicationDidEnterBackground:(NSNotification *)note {

	BOOL saved = [NSKeyedArchiver archiveRootObject:self toFile:[[self class] archivePath]];
	if (!saved) {
		NSLog(@"Unable to save WACacheManager");
	}

}

- (void)initCacheEntities {

	__weak WACacheManager *wSelf = self;
	NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
	[context performBlock:^{
		NSArray *files = [[WADataStore defaultStore] fetchAllFilesUsingContext:context];
		for (WAFile *file in files) {
			if ([[file caches] count] == 0) {
				NSMutableArray *caches = [[NSMutableArray alloc] init];
				NSArray *keyPaths = @[@"extraSmallThumbnailFilePath", @"smallThumbnailFilePath", @"thumbnailFilePath", @"largeThumbnailFilePath", @"resourceFilePath"];
				for (NSString *keyPath in keyPaths) {
					if ([file valueForKey:keyPath]) {
						NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[file valueForKey:keyPath] error:nil];
						WACache *cache = [WACache objectInsertingIntoContext:context withRemoteDictionary:@{}];
						[cache setLastAccessTime:[NSDate date]];
						[cache setKeyPath:[NSString stringWithFormat:@"file.%@", keyPath]];
						[cache setFileSize:[attributes objectForKey:NSFileSize]];
						[caches addObject:cache];
					}
				}
				if ([caches count]) {
					[file setCaches:[[NSSet alloc] initWithArray:caches]];
				}
				NSError *error = nil;
				[context save:&error];
				if (error) {
					NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, error);
				}
			}
		}
		
		NSArray *ogImages = [[WADataStore defaultStore] fetchAllOGImagesUsingContext:context];
		for (WAOpenGraphElementImage *ogImage in ogImages) {
			if (![ogImage cache]) {
				NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[ogImage imageFilePath] error:nil];
				WACache *cache = [WACache objectInsertingIntoContext:context withRemoteDictionary:@{}];
				[cache setLastAccessTime:[NSDate date]];
				[cache setKeyPath:@"ogimage.imageFilePath"];
				[cache setFileSize:[attributes objectForKey:NSFileSize]];
				[ogImage setCache:cache];
			}
			NSError *error = nil;
			[context save:&error];
			if (error) {
				NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, error);
			}
		}

		[wSelf setConstructionFinished:YES];
	}];

}

- (void)clearPurgeableFilesIfNeeded {

	WADataStore *ds = [WADataStore defaultStore];
	NSManagedObjectContext *context = [ds disposableMOC];
	[context performBlock:^{

		NSUInteger const limitSize = 600*1024*1024;	//600MB
		NSUInteger totalSize = [[ds fetchTotalCacheSizeUsingContext:context] unsignedIntegerValue];
		if (totalSize > limitSize) {

			NSLog(@"Total cache size is over %d, clear purgeable files now...", limitSize);
			NSArray *caches = [ds fetchAllCachesUsingContext:context];
			for (WACache *cache in caches) {
				if ([[self delegate] shouldPurgeCachedFile:cache]) {
					NSString *filePath = [cache valueForKeyPath:[cache keyPath]];
					NSError *error = nil;
					[[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
					if (error) {
						NSLog(@"Unable to remove cached file: %s %@", __PRETTY_FUNCTION__, error);
					} else {
						[cache setValue:nil forKeyPath:[cache keyPath]];
						[context deleteObject:cache];
						error = nil;
						[context save:&error];
						if (error) {
							NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, error);
						}
						totalSize -= [[cache fileSize] unsignedIntegerValue];
					}
				}
				if (totalSize <= limitSize) {
					break;
				}
			}
			NSLog(@"Purging finished, current total size is %d", totalSize);

		} else {

			NSLog(@"Total cache size is under %d, no need purging", limitSize);

		}

	}];
	
}

+ (NSString *)archivePath {

	NSArray *cacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cacheDirectory = [cacheDirectories objectAtIndex:0];
	return [cacheDirectory stringByAppendingPathComponent:@"cachemanager.archive"];

}
	
@end
