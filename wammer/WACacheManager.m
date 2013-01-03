//
//  WACacheManager.m
//  wammer
//
//  Created by kchiu on 12/10/8.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WACacheManager.h"
#import "WADataStore.h"
#import "WAFile+WAConstants.h"

NSString * const kWACacheSize = @"WACacheSize";
NSString * const kWACacheFilePathKey = @"filePathKey";
NSString * const kWACacheFilePath = @"filePath";
NSUInteger const DEFAULT_CACHE_SIZE = 600*1024*1024; //600MB

@interface WACacheManager ()

@property (nonatomic, readwrite) NSUInteger size;

- (void)initCacheEntities;

@end


@implementation WACacheManager

- (id)init {
  
  self = [super init];
  if (self) {
    self.size = [[NSUserDefaults standardUserDefaults] integerForKey:kWACacheSize];
    if (self.size == 0) {
      [self initCacheEntities];
    }
  }
  return self;
  
}

- (void)initCacheEntities {
  
  // the following two loops over files and ogimages is for migration,
  // since we do not support migration from old client anymore,
  // it's ok to keep them here, even in main thread.
  NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
  
  NSArray *files = [[WADataStore defaultStore] fetchAllFilesUsingContext:context];
  for (WAFile *file in files) {
    if (!file.caches) {
      NSArray *pathKeys = @[kWAFileExtraSmallThumbnailFilePath,
      kWAFileSmallThumbnailFilePath,
      kWAFileThumbnailFilePath,
      kWAFileLargeThumbnailFilePath,
      kWAFileResourceFilePath];
      for (NSString *pathKey in pathKeys) {
        // create cache entity by touching file path
        NSString *filePath = [file valueForKey:pathKey];
        if (filePath) {
	NSLog(@"Init cache entity for attachment file at: %@", filePath);
        }
      }
    }
  }
  
  NSArray *ogImages = [[WADataStore defaultStore] fetchAllOGImagesUsingContext:context];
  for (WAOpenGraphElementImage *ogImage in ogImages) {
    if (!ogImage.cache) {
      // create cache entity by touching file path
      NSString *filePath = ogImage.imageFilePath;
      if (filePath) {
        NSLog(@"Init cache entity for ogimage file at: %@", filePath);
      }
    }
  }
  
  __weak WACacheManager *wSelf = self;
  WADataStore *ds = [WADataStore defaultStore];
  [ds performBlock:^{

    // set cache size in the last step of initialization
    wSelf.size = DEFAULT_CACHE_SIZE;
    
    // save cache size to disk so that we don't need to initialize cache entities next time.
    [[NSUserDefaults standardUserDefaults] setInteger:DEFAULT_CACHE_SIZE forKey:kWACacheSize];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSUInteger totalSize = [[ds fetchTotalCacheSizeUsingContext:[ds disposableMOC]] unsignedIntegerValue];
    NSLog(@"Cache entries are successfully initialized, total size is %d", totalSize);

  } waitUntilDone:YES];
  
}

- (void)insertOrUpdateCacheWithRelationship:(NSURL *)relationshipURL filePath:(NSString *)filePath filePathKey:(NSString *)filePathKey {
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
    NSLog(@"File does not exist: %@", filePath);
  }
  
  WADataStore *ds = [WADataStore defaultStore];
  [ds performBlock:^{
    
    NSManagedObjectContext *context = [ds disposableMOC];
    
    id relatedObject = [context irManagedObjectForURI:relationshipURL];
    
    BOOL isWAFile = [relatedObject isKindOfClass:[WAFile class]];
    BOOL isWAOpenGraphElementImage = [relatedObject isKindOfClass:[WAOpenGraphElementImage class]];
    BOOL isWAFilePageElement = [relatedObject isKindOfClass:[WAFilePageElement class]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ && %K == %@", kWACacheFilePathKey, filePathKey, kWACacheFilePath, filePath];
    WACache *currentCache = [[WADataStore defaultStore] fetchCacheWithPredicate:predicate usingContext:context];
    WACache *savedCache = nil;
    
    if (currentCache) {
      
      currentCache.lastAccessTime = [NSDate date];
      
    } else {
      
      savedCache = [WACache objectInsertingIntoContext:context withRemoteDictionary:@{}];
      savedCache.lastAccessTime = [NSDate date];
      savedCache.filePath = filePath;
      savedCache.filePathKey = filePathKey;
      NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
      savedCache.fileSize = [attributes objectForKey:NSFileSize];
      
      if (isWAFile) {
        savedCache.file = (WAFile *)relatedObject;
      } else if (isWAOpenGraphElementImage) {
        savedCache.ogimage = (WAOpenGraphElementImage *)relatedObject;
      } else if (isWAFilePageElement) {
        savedCache.pageElement = (WAFilePageElement *)relatedObject;
      }
      
    }
    
    [context save:nil];
    
  } waitUntilDone:NO];
  
}

- (void)clearPurgeableFilesIfNeeded {
  
  __weak WACacheManager *wSelf = self;
  if ([NSThread isMainThread]) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [wSelf clearPurgeableFilesIfNeeded];
    });
    return;
  }
  
  if (self.size == 0) {
    NSLog(@"Cache entities has not been initialized yet, skip it");
    return;
  }
  
  WADataStore *ds = [WADataStore defaultStore];
  __block NSUInteger totalSize = [[ds fetchTotalCacheSizeUsingContext:[ds disposableMOC]] unsignedIntegerValue];
  
  if (totalSize > self.size) {
    
    NSLog(@"Total cache size is over %d, clear purgeable files now...", self.size);
    
    __weak WACacheManager *wSelf = self;
    NSArray *caches = [ds fetchAllCachesUsingContext:[ds disposableMOC]];
    
    for (WACache *cache in caches) {
      
      [ds performBlock:^{
        
        if (totalSize <= wSelf.size) {
	return;
        }
        
        NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
        
        // deleting a WACache object from different context is forbidden, so we do select again
        WACache *targetCache = (WACache *)[context irManagedObjectForURI:[[cache objectID] URIRepresentation]];
        
        if ([wSelf.delegate shouldPurgeCachedFile:targetCache]) {
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:targetCache.filePath]) {
	  NSError *error = nil;
	  [[NSFileManager defaultManager] removeItemAtPath:targetCache.filePath error:&error];
	  if (error) {
	    NSLog(@"Unable to remove cached file: %s %@", __PRETTY_FUNCTION__, error);
	    return;
	  }
	}
	
	totalSize -= [targetCache.fileSize unsignedIntegerValue];
	[context deleteObject:targetCache];
	
	NSError *error = nil;
	[context save:&error];
	if (error) {
	  NSLog(@"Error saving: %s %@", __PRETTY_FUNCTION__, error);
	}
        }
        
      } waitUntilDone:NO];
      
    }
    
    [ds performBlock:^{
      NSLog(@"Purging finished, current total size is %d", totalSize);
    } waitUntilDone:NO];
    
  } else {
    
    NSLog(@"Total cache size is under %d, no need purging", self.size);
    
  }
  
}

@end
