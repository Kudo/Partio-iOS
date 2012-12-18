//
//  WAFile+WARemoteInterfaceEntitySyncing.m
//  wammer
//
//  Created by Evadne Wu on 11/9/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "IRAsyncOperation.h"

#import "WAFile+WARemoteInterfaceEntitySyncing.h"
#import "WADataStore.h"
#import "WARemoteInterface.h"
#import "WADefines.h"

#import "UIImage+WAAdditions.h"
#import "ALAssetRepresentation+IRAdditions.h"
#import "WAFile+ThumbnailMaker.h"
#import "WAAssetsLibraryManager.h"

#import "NSDate+WAAdditions.h"

#import "SSToolkit/NSDate+SSToolkitAdditions.h"


NSString * kWAFileEntitySyncingErrorDomain = @"com.waveface.wammer.file.entitySyncing";
NSError * WAFileEntitySyncingError (NSUInteger code, NSString *descriptionKey, NSString *reasonKey) {
	return [NSError irErrorWithDomain:kWAFileEntitySyncingErrorDomain code:code descriptionLocalizationKey:descriptionKey reasonLocalizationKey:reasonKey userInfo:nil];
}

NSString * const kWAFileSyncStrategy = @"WAFileSyncStrategy";
NSString * const kWAFileSyncDefaultStrategy = @"WAFileSyncDefaultStrategy";
NSString * const kWAFileSyncAdaptiveQualityStrategy = @"WAFileSyncAdaptiveQualityStrategy";
NSString * const kWAFileSyncReducedQualityStrategy = @"WAFileSyncReducedQualityStrategy";
NSString * const kWAFileSyncFullQualityStrategy = @"WAFileSyncFullQualityStrategy";


@implementation WAFile (WARemoteInterfaceEntitySyncing)

- (void) configureWithRemoteDictionary:(NSDictionary *)inDictionary {
 
	NSMutableDictionary *usedDictionary = [inDictionary mutableCopy];
  
  if ([usedDictionary[@"url"] isEqualToString:@""])
    [usedDictionary removeObjectForKey:@"url"];
	
  [super configureWithRemoteDictionary:usedDictionary];
  
  if (!self.resourceType) {
    
    NSString *pathExtension = [self.remoteFileName pathExtension];
    if (pathExtension) {
      
      CFStringRef preferredUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExtension, NULL);
      self.resourceType = (__bridge_transfer NSString *)preferredUTI;

    }
    
  }
  
}

+ (NSString *) keyPathHoldingUniqueValue {

	return @"identifier";

}

+ (BOOL) skipsNonexistantRemoteKey {

	//	Allows piecemeal data patching, by skipping code path that assigns a placeholder value for any missing value
	//	that -configureWithRemoteDictionary: gets
	return YES;
	
}

+ (NSDictionary *) remoteDictionaryConfigurationMapping {

	static NSDictionary *mapping = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    
		mapping = @{
			@"code_name": @"codeName",
			
			@"description": @"text",
			@"device_id": @"creationDeviceIdentifier",
			@"file_name": @"remoteFileName",
			@"file_size": @"remoteFileSize",
			@"event_time": @"created",
			@"dayOnCreation": @"dayOnCreation",
		  @"doc_access_time": @"docAccessTime",
			
			@"image": @"remoteRepresentedImage",
			@"md5": @"remoteResourceHash",
			@"mime_type": @"resourceType",
			@"object_id": @"identifier",
			@"title": @"title",
			@"type": @"remoteResourceType",
			
			@"small_thumbnail_url": @"smallThumbnailURL",
			@"thumbnail_url": @"thumbnailURL",
			@"large_thumbnail_url": @"largeThumbnailURL",
			
			@"url": @"resourceURL",
			@"file_create_time": @"timestamp",
      
			@"pageElements": @"pageElements",
							 
			@"web_url": @"webURL",
			@"web_title": @"webTitle",
			@"web_favicon": @"webFaviconURL"};
		
	});

	return mapping;

}

+ (NSDictionary *) defaultHierarchicalEntityMapping {

	return @{@"pageElements": @"WAFilePageElement"};

}

+ (NSDictionary *) transformedRepresentationForRemoteRepresentation:(NSDictionary *)incomingRepresentation {

	NSMutableDictionary *returnedDictionary = [incomingRepresentation mutableCopy];

	NSString *smallImageRepURLString = [returnedDictionary valueForKeyPath:@"image_meta.small.url"];
	if ([smallImageRepURLString isKindOfClass:[NSString class]])
    returnedDictionary[@"small_thumbnail_url"] = smallImageRepURLString;
 
	NSString *mediumImageRepURLString = [returnedDictionary valueForKeyPath:@"image_meta.medium.url"];
	if ([mediumImageRepURLString isKindOfClass:[NSString class]])
    returnedDictionary[@"thumbnail_url"] = mediumImageRepURLString;
  
	NSString *largeImageRepURLString = [returnedDictionary valueForKeyPath:@"image_meta.large.url"];
	if ([largeImageRepURLString isKindOfClass:[NSString class]])
    returnedDictionary[@"large_thumbnail_url"] = largeImageRepURLString;
	
	NSString *eventDateTime = incomingRepresentation[@"event_time"];
	if ([eventDateTime isKindOfClass:[NSString class]]) {
		[returnedDictionary setObject:eventDateTime forKey:@"dayOnCreation"];
	}
	
	NSString *incomingFileType = incomingRepresentation[@"type"];	
  
  if ([incomingFileType isEqualToString:@"image"]) {
  
    NSString *webURLString = [incomingRepresentation valueForKeyPath:@"image_meta.web_url"];
		if ([webURLString isKindOfClass:[NSString class]])
			returnedDictionary[@"web_url"] = webURLString;
		
		NSString *webFaviconURLString = [incomingRepresentation valueForKeyPath:@"image_meta.web_favicon"];
		if ([webFaviconURLString isKindOfClass:[NSString class]])
			returnedDictionary[@"web_favicon"] = webFaviconURLString;
		
		NSString *webTitleString = [incomingRepresentation valueForKeyPath:@"image_meta.web_title"];
		if ([webTitleString isKindOfClass:[NSString class]])
			returnedDictionary[@"web_title"] = webTitleString;
		
  
  } else if ([incomingFileType isEqualToString:@"doc"]) {
  
		if (incomingRepresentation[@"doc_meta"]) {

			returnedDictionary[@"file_name"] = [incomingRepresentation valueForKeyPath:@"doc_meta.file_name"];
			returnedDictionary[@"doc_access_time"] = [incomingRepresentation valueForKeyPath:@"doc_meta.access_time"];
			
			NSNumber *pagesValue = [incomingRepresentation valueForKeyPath:@"doc_meta.preview_pages"];
			
			if ([pagesValue isKindOfClass:[NSNumber class]]) {
				
				NSUInteger numberOfPages = [pagesValue unsignedIntegerValue];
				
				NSMutableArray *returnedArray = [NSMutableArray array];
				NSString *ownObjectID = [incomingRepresentation valueForKeyPath:@"object_id"];
				
				for (NSUInteger i = 0; i < numberOfPages; i++) {
					NSURL *previewURL = [[NSURL URLWithString:@"http://invalid.local"] URLByAppendingPathComponent:@"v2/attachments/view"];
					NSDictionary *parameters = @{@"object_id": ownObjectID, @"target": @"preview", @"page": @(i + 1)};
					NSDictionary *pageElement = @{
						@"thumbnailURL": [IRWebAPIRequestURLWithQueryParameters(previewURL, parameters) absoluteString],
						@"page": @(i + 1)
					};
					[returnedArray addObject:pageElement];
				}
				
				returnedDictionary[@"pageElements"] = returnedArray;
			}

		}
  
  } else if ([incomingFileType isEqualToString:@"text"]) {
    
    // ?
      
  }
	
	return returnedDictionary; 

}

+ (id) transformedValue:(id)aValue fromRemoteKeyPath:(NSString *)aRemoteKeyPath toLocalKeyPath:(NSString *)aLocalKeyPath {

  if ([aLocalKeyPath isEqualToString:@"remoteFileSize"]) {
    
    if ([aValue isEqual:@""])
      return nil;
  
    if ([aValue isKindOfClass:[NSNumber class]])
      return aValue;
    
    return @([aValue unsignedIntValue]);
    
  }
  
	if ([aLocalKeyPath isEqualToString:@"timestamp"] || [aLocalKeyPath isEqualToString:@"created"] || [aLocalKeyPath isEqualToString:@"docAccessTime"]) {
		return [NSDate dateFromISO8601String:aValue];
	}
	
	if ([aLocalKeyPath isEqualToString:@"dayOnCreation"])
		return [[NSDate dateFromISO8601String:aValue] dayBegin];
	
	if ([aLocalKeyPath isEqualToString:@"identifier"])
		return IRWebAPIKitStringValue(aValue);
		
	if ([aLocalKeyPath isEqualToString:@"resourceType"]) {
	
		if (UTTypeConformsTo((__bridge CFStringRef)aValue, kUTTypeItem))
			return aValue;
		 
		id returnedValue = IRWebAPIKitStringValue(aValue);
		
		NSArray *possibleTypes = (__bridge_transfer NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassMIMEType, (__bridge CFStringRef)returnedValue, nil);
		
		if ([possibleTypes count]) {
			returnedValue = possibleTypes[0];
		}
    
    //  Incoming stuff is moot (“application/unknown”)
    
    if ([returnedValue hasPrefix:@"dyn."])
      return nil;
    
		return returnedValue;
		
	}
	
	if ([aLocalKeyPath isEqualToString:@"resourceURL"] || 
		[aLocalKeyPath isEqualToString:@"largeThumbnailURL"] || 
		[aLocalKeyPath isEqualToString:@"thumbnailURL"] ||
		[aLocalKeyPath isEqualToString:@"smallThumbnailURL"]) {
	
    if (![aValue length])
      return nil;
  
		NSString *usedPath = [aValue hasPrefix:@"/"] ? aValue : [@"/" stringByAppendingString:aValue];
		return [[NSURL URLWithString:usedPath relativeToURL:[NSURL URLWithString:@"http://invalid.local"]] absoluteString];
    
	}
	
	return [super transformedValue:aValue fromRemoteKeyPath:aRemoteKeyPath toLocalKeyPath:aLocalKeyPath];

}

+ (void) synchronizeWithCompletion:(void (^)(BOOL, NSError *))completionBlock {

  [self synchronizeWithOptions:nil completion:completionBlock];
  
}

+ (void) synchronizeWithOptions:(NSDictionary *)options completion:(WAEntitySyncCallback)completionBlock {

  [NSException raise:NSInternalInconsistencyException format:@"%@ does not support %@.", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
  
}

- (void) synchronizeWithCompletion:(WAEntitySyncCallback)completionBlock {

  [self synchronizeWithOptions:nil completion:completionBlock];
  
}	

- (void) synchronizeWithOptions:(NSDictionary *)options completion:(WAEntitySyncCallback)completionBlock {

	if (!WAIsSyncableObject(self)) {
		
		if (completionBlock)
			completionBlock(NO, nil);
		
		return;
	
	}
	
	WAFileSyncStrategy syncStrategy = options[kWAFileSyncStrategy];
	if (!syncStrategy)
		syncStrategy = kWAFileSyncAdaptiveQualityStrategy;

	WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
	WADataStore * const ds = [WADataStore defaultStore];
	NSURL * const ownURL = [[self objectID] URIRepresentation];
	
	BOOL areExpensiveOperationsAllowed = [ri areExpensiveOperationsAllowed];
	
	BOOL canSendResourceImage = NO;
	BOOL canSendThumbnailImage = NO;
	
	if ([syncStrategy isEqual:kWAFileSyncAdaptiveQualityStrategy]) {
	
		canSendResourceImage = areExpensiveOperationsAllowed;
		canSendThumbnailImage = YES;
	
	} else if ([syncStrategy isEqual:kWAFileSyncReducedQualityStrategy]) {
	
		canSendResourceImage = NO;
		canSendThumbnailImage = YES;
	
	} else if ([syncStrategy isEqual:kWAFileSyncFullQualityStrategy]) {
	
		canSendResourceImage = YES;
		canSendThumbnailImage = NO;
	
	}
	
	
	/* Steven: for redmine #1701, there is a strange issue, when we check [self smallestPresentableImage] for needsSendingThumbnailImage here,
	 * this will cause the second and other photos will not be copied from Asset Library, an unknown hang in operation queue. 
	 * The root cause is unknown. But if we didn't call smallestPresetableImage here, it would work fine. As a workaround, we don't test this here
	 * And not to invoke smallestPresentableImage for needsSendingThumbnailImage should be fine
	 */
	BOOL needsSendingResourceImage = !self.resourceURL;
	BOOL needsSendingThumbnailImage = !self.thumbnailURL;
	
	NSMutableArray *operations = [NSMutableArray array];
	
	BOOL (^isValidPath)(NSString *) = ^ (NSString *aPath) {
		
		//	Bug with extensions:
		//	“application/octet-stream”
		//	crumbles our server
		
		if (![[aPath pathExtension] length])
			return NO;
		
		BOOL isDirectory = NO;
		if (![[NSFileManager defaultManager] fileExistsAtPath:aPath isDirectory:&isDirectory])
			return NO;
		
		return (BOOL)!isDirectory;
	
	};
	
	void (^uploadAttachment)(NSURL *, NSMutableDictionary *, IRAsyncOperationCallback) = ^ (NSURL *fileURL, NSMutableDictionary *options, IRAsyncOperationCallback callback) {
		
		NSParameterAssert(fileURL);
		
		if (![[NSUserDefaults standardUserDefaults] boolForKey:kWAPhotoImportEnabled]) {
			callback(WAFileEntitySyncingError(0, @"Photo import is disabled, stop sync files", nil));
			return;
		}
		
		WARemoteInterface *ri = [WARemoteInterface sharedInterface];
		
		[ri createAttachmentWithFile:fileURL group:ri.primaryGroupIdentifier options:options onSuccess: ^ (NSString *attachmentIdentifier) {
			
			NSManagedObjectContext *context = [ds autoUpdatingMOC];
			context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

			WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
			file.identifier = attachmentIdentifier;
			
			if ([[options valueForKey:kWARemoteAttachmentSubtype] isEqualToString:WARemoteAttachmentMediumSubtype]) {
				
				file.thumbnailURL = [[file class] transformedValue:[@"/v2/attachments/view?object_id=" stringByAppendingFormat:@"%@&image_meta=medium", file.identifier] fromRemoteKeyPath:nil toLocalKeyPath:@"thumbnailURL"];
				
			} else if ([[options valueForKey:kWARemoteAttachmentSubtype] isEqualToString:WARemoteAttachmentOriginalSubtype]) {
				
				file.resourceURL = [[file class] transformedValue:[@"/v2/attachments/view?object_id=" stringByAppendingFormat:@"%@", file.identifier] fromRemoteKeyPath:nil toLocalKeyPath:@"resourceURL"];
				
				[[WADataStore defaultStore] setLastSyncSuccessDate:[NSDate date]];
				
			}
			
			NSError *error = nil;
			BOOL didSave = [context save:&error];
			NSCAssert1(didSave, @"Generated thumbnail uploaded but metadata is not saved correctly: %@", error);
			
			callback(error);
			
		} onFailure: ^ (NSError *error) {
			
			// file is existed
			if ([[error domain] isEqualToString:kWARemoteInterfaceDomain] && [error code] == 0x6000 + 14) {

				NSManagedObjectContext *context = [ds autoUpdatingMOC];
				context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

				WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
				
				if ([[options valueForKey:kWARemoteAttachmentSubtype] isEqualToString:WARemoteAttachmentMediumSubtype]) {
					
					file.thumbnailURL = [[file class] transformedValue:[@"/v2/attachments/view?object_id=" stringByAppendingFormat:@"%@&image_meta=medium", file.identifier] fromRemoteKeyPath:nil toLocalKeyPath:@"thumbnailURL"];
					
				} else if ([[options valueForKey:kWARemoteAttachmentSubtype] isEqualToString:WARemoteAttachmentOriginalSubtype]) {
					
					file.resourceURL = [[file class] transformedValue:[@"/v2/attachments/view?object_id=" stringByAppendingFormat:@"%@", file.identifier] fromRemoteKeyPath:nil toLocalKeyPath:@"resourceURL"];
					
					[[WADataStore defaultStore] setLastSyncSuccessDate:[NSDate date]];
					
				}
				
				NSError *error = nil;
				BOOL didSave = [context save:&error];
				NSCAssert1(didSave, @"Generated thumbnail uploaded but metadata is not saved correctly: %@", error);
				
				callback(error);
				
			} else {
				
				callback(error);

			}
			
		}];
		
	};

	if (needsSendingThumbnailImage && canSendThumbnailImage) {
		
		/* this probably won't happen since all selected photos will be generated with thumbnails while composition
		 */

		[operations addObject:[IRAsyncBarrierOperation operationWithWorker:^(IRAsyncOperationCallback callback) {

			NSManagedObjectContext *context = [ds autoUpdatingMOC];
			context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
			
			WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
			
			if (file.thumbnailURL) {
				callback(nil);
				return;
			}
			
			NSString *thumbnailFilePath = file.thumbnailFilePath;
			
			NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
																			@(WARemoteAttachmentImageType), kWARemoteAttachmentType,
																			WARemoteAttachmentMediumSubtype, kWARemoteAttachmentSubtype,
																			nil];
			
			if (file.identifier) {
				options[kWARemoteAttachmentUpdatedObjectIdentifier] = file.identifier;
			}
			
			NSAssert1(file.articles.count>0, @"WAFile entity %@ must have already been associated with an article", file);
			WAArticle *article = [file.articles allObjects][0];  // if the post is from device itself, there should be only one article in db, this should be right, but careful
			if (article.identifier) {
				options[kWARemoteArticleIdentifier] = article.identifier;
			}
			
			if (file.exif) {
				options[kWARemoteAttachmentExif] = file.exif;
			}
			
			if (file.importTime) {
				options[kWARemoteAttachmentImportTime] = file.importTime;
			}
			
			if (!isValidPath(thumbnailFilePath)) {
				
				if (file.assetURL) {
					
					[[WAAssetsLibraryManager defaultManager] assetForURL:[NSURL URLWithString:file.assetURL] resultBlock:^(ALAsset *asset) {
						
						UIImage *image = [[asset defaultRepresentation] irImage];
						[file makeThumbnailsWithImage:image  options:WAThumbnailMakeOptionMedium];
						
						NSError *error = nil;
						BOOL didSave = [context save:&error];
						NSCAssert1(didSave, @"Generated thumbnail could not be saved: %@", error);
						
						uploadAttachment([NSURL fileURLWithPath:file.thumbnailFilePath], options, callback);
						
					} failureBlock:^(NSError *error) {
						
						NSLog(@"Unable to read asset from url: %@", file.assetURL);
						callback(error);
						
					}];
					
				} else {
					
					UIImage *bestImage = [file resourceImage];
					if (! bestImage)
						bestImage = [file bestPresentableImage];
					if (!bestImage) {
						NSLog(@"bestImage of file %@ does not exist", [file identifier]);
						callback(nil);
						return;
					}
					NSCParameterAssert(bestImage);
					
					[file makeThumbnailsWithImage:bestImage options:WAThumbnailMakeOptionMedium];
					
					NSError *error = nil;
					BOOL didSave = [context save:&error];
					NSCAssert1(didSave, @"Generated thumbnail could not be saved: %@", error);
					
					uploadAttachment([NSURL fileURLWithPath:file.thumbnailFilePath], options, callback);
					
				}
				
			} else {
				
				uploadAttachment([NSURL fileURLWithPath:file.thumbnailFilePath], options, callback);
				
			}
		
		} trampoline:^(IRAsyncOperationInvoker callback) {

			callback();

		} callback:^(id results) {

			if ([results isKindOfClass:[NSError class]]) {
				completionBlock(NO, results);
			} else {
				completionBlock(YES, nil);
			}

		} callbackTrampoline:^(IRAsyncOperationInvoker callback) {

			callback();
		
		}]];
	
	}
	
	if (needsSendingResourceImage && canSendResourceImage) {

		[operations addObject:[IRAsyncBarrierOperation operationWithWorker:^(IRAsyncOperationCallback callback) {

			NSManagedObjectContext *context = [ds disposableMOC];
			
			WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
			
			if (file.resourceURL || ![[WARemoteInterface sharedInterface] hasReachableStation]) {
				callback(nil);
				return;
			}
			
			NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
																			@(WARemoteAttachmentImageType), kWARemoteAttachmentType,
																			WARemoteAttachmentOriginalSubtype, kWARemoteAttachmentSubtype,
																			nil];
			
			if (file.identifier)
				options[kWARemoteAttachmentUpdatedObjectIdentifier] = file.identifier;
			
			WAArticle *article = [file.articles allObjects][0];
			if (article.identifier) {
				options[kWARemoteArticleIdentifier] = article.identifier;
			}
			
			if (file.exif) {
				options[kWARemoteAttachmentExif] = file.exif;
			}
			
			if (file.timestamp) {
				options[kWARemoteAttachmentCreateTime] = file.timestamp;
			}
			
			if (file.importTime) {
				options[kWARemoteAttachmentImportTime] = file.importTime;
			}
			
			NSString *sentResourcePath = file.resourceFilePath;
			if (!isValidPath(sentResourcePath)) {
				if (file.assetURL) {
					uploadAttachment([NSURL URLWithString:file.assetURL], options, callback);
				}
			} else {
				uploadAttachment([NSURL fileURLWithPath:sentResourcePath], options, callback);
			}

		} trampoline:^(IRAsyncOperationInvoker callback) {

			callback();

		} callback:^(id results) {

			if ([results isKindOfClass:[NSError class]]) {
				completionBlock(NO, results);
			} else {
				completionBlock(YES, nil);
			}

		} callbackTrampoline:^(IRAsyncOperationInvoker callback) {

			callback();

		}]];
	
	}

	[operations enumerateObjectsUsingBlock:^(IRAsyncBarrierOperation *op, NSUInteger idx, BOOL *stop) {
		if (idx > 0)
			[op addDependency:(IRAsyncBarrierOperation *)operations[(idx - 1)]];
	}];
	
	[[[self class] sharedSyncQueue] addOperations:operations waitUntilFinished:NO];

}

+ (NSOperationQueue *) sharedSyncQueue {
	
	static NSOperationQueue *queue = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    
		queue = [[NSOperationQueue alloc] init];
		queue.maxConcurrentOperationCount = 1;
		
	});
	
	return queue;
	
}

@end
