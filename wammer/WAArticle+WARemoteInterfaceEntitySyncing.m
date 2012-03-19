//
//  WAArticle+WARemoteInterfaceEntitySyncing.m
//  wammer
//
//  Created by Evadne Wu on 11/9/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticle+WARemoteInterfaceEntitySyncing.h"
#import "WAFile+WARemoteInterfaceEntitySyncing.h"
#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "Foundation+IRAdditions.h"
#import "IRAsyncOperation.h"


NSString * const kWAArticleEntitySyncingErrorDomain = @"com.waveface.wammer.WAArticle.entitySyncing.error";
NSError * WAArticleEntitySyncingError (NSUInteger code, NSString *descriptionKey, NSString *reasonKey) {
	return [NSError irErrorWithDomain:kWAArticleEntitySyncingErrorDomain code:0 descriptionLocalizationKey:descriptionKey reasonLocalizationKey:reasonKey userInfo:nil];
}

NSString * const kWAArticleSyncStrategy = @"WAArticleSyncStrategy";
NSString * const kWAArticleSyncDefaultStrategy = @"WAArticleSyncMergeLastBatchStrategy";
NSString * const kWAArticleSyncFullyFetchOnlyStrategy = @"WAArticleSyncFullyFetchOnlyStrategy";
NSString * const kWAArticleSyncMergeLastBatchStrategy = @"WAArticleSyncMergeLastBatchStrategy";

NSString * const kWAArticleSyncRangeStart = @"WAArticleSyncRangeStart";
NSString * const kWAArticleSyncRangeEnd = @"WAArticleSyncRangeEnd";

NSString * const kWAArticleSyncSessionInfo = @"WAArticleSyncSessionInfo";

@implementation WAArticle (WARemoteInterfaceEntitySyncing)

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
    
		mapping = [NSDictionary dictionaryWithObjectsAndKeys:
		
		/*
		
		    post_id: <post_id>,     // unique   
    creator_id: <uid>,
    code_name: (String) nameOfCreatingDevice,
    group_id: <group_id>,
    timestamp: (Date) aTimestamp,
    content: (String) contentText,
    comment_count: (Number) numberOfComments,
    comments: (Array) zeroOrMoreCommentEntities,
    attachment_id_array: (Array) arrayOfAttachmentId,
    attachments_count: (Number) numberOfFiles,
    attachments: (Array) zeroOrMoreFileEntities,
    preview: (Array) zeroOrMore PreviewEntities,
    soul: aSoulEntity

		
		*/
		
			@"identifier", @"post_id",
			@"owner", @"owner",	//	wraps @"creator_id"
			@"creationDeviceName", @"code_name",
			@"group", @"group",	//	wraps @"group_id"
			@"timestamp", @"timestamp",
			@"text", @"content",
			@"comments", @"comments",
			@"files", @"attachments",
			@"previews", @"previews",
			
			@"summary", @"soul",
			
		nil];
		
	});

	return mapping;

}

+ (id) transformedValue:(id)aValue fromRemoteKeyPath:(NSString *)aRemoteKeyPath toLocalKeyPath:(NSString *)aLocalKeyPath {

	if ([aLocalKeyPath isEqualToString:@"timestamp"])
		return [[WADataStore defaultStore] dateFromISO8601String:aValue];
	
	if ([aLocalKeyPath isEqualToString:@"identifier"])
		return IRWebAPIKitStringValue(aValue);
	
	return [super transformedValue:aValue fromRemoteKeyPath:aRemoteKeyPath toLocalKeyPath:aLocalKeyPath];

}

+ (NSDictionary *) defaultHierarchicalEntityMapping {

	return [NSDictionary dictionaryWithObjectsAndKeys:
		
		//	@"WAFile", @"files",
		@"WAGroup", @"group",
		@"WAComment", @"comments",
		@"WAUser", @"owner",
		@"WAPreview", @"previews",
		@"WAFile", @"attachments",
	
	nil];

}

+ (NSDictionary *) transformedRepresentationForRemoteRepresentation:(NSDictionary *)incomingRepresentation {

	NSMutableDictionary *returnedDictionary = [incomingRepresentation mutableCopy];

	NSString *creatorID = [incomingRepresentation objectForKey:@"creator_id"];
	NSString *articleID = [incomingRepresentation objectForKey:@"post_id"];
	NSString *groupID = [incomingRepresentation objectForKey:@"group_id"];

	if (creatorID)
		[returnedDictionary setObject:[NSDictionary dictionaryWithObject:creatorID forKey:@"user_id"] forKey:@"owner"];

	if (groupID)
		[returnedDictionary setObject:[NSDictionary dictionaryWithObject:groupID forKey:@"group_id"] forKey:@"group"];
	
	NSArray *comments = [incomingRepresentation objectForKey:@"comments"];
	if ([comments count] && articleID) {
	
		NSMutableArray *transformedComments = [comments mutableCopy];
		
		[comments enumerateObjectsUsingBlock: ^ (NSDictionary *aCommentRep, NSUInteger idx, BOOL *stop) {
		
			NSMutableDictionary *transformedComment = [aCommentRep mutableCopy];
			NSString *commentID = [transformedComment objectForKey:@"comment_id"];
			id aTimestamp = [aCommentRep objectForKey:@"timestamp"];
			if (!aTimestamp)
				aTimestamp = IRWebAPIKitNonce();
			
			if (!commentID) {
				commentID = [NSString stringWithFormat:@"Synthesized_Article_%@_Timestamp_%@", articleID, aTimestamp];
				[transformedComment setObject:commentID forKey:@"comment_id"];
			}
			
			[transformedComments replaceObjectAtIndex:idx withObject:transformedComment];
			
		}];
		
		[returnedDictionary setObject:transformedComments forKey:@"comments"];
	
	}
	
	NSDictionary *preview = [incomingRepresentation objectForKey:@"preview"];
	
	if ([preview count]) {
	
		[returnedDictionary setObject:[NSArray arrayWithObjects:
		
			[NSDictionary dictionaryWithObjectsAndKeys:
			
				preview, @"og",
				[preview valueForKeyPath:@"url"], @"id",
			
			nil],
		
		nil] forKey:@"previews"];
	
	}
	
	return returnedDictionary;

}

+ (void) synchronizeWithCompletion:(void (^)(BOOL, NSManagedObjectContext *, NSArray *, NSError *))completionBlock {

  [self synchronizeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:
  
    kWAArticleSyncMergeLastBatchStrategy, kWAArticleSyncStrategy,
  
  nil] completion:completionBlock];

}

+ (void) synchronizeWithOptions:(NSDictionary *)options completion:(void (^)(BOOL, NSManagedObjectContext *, NSArray *, NSError *))completionBlock {

  WAArticleSyncStrategy syncStrategy =	[options objectForKey:kWAArticleSyncStrategy];
  
  WARemoteInterface *ri = [WARemoteInterface sharedInterface];
  WADataStore *ds = [WADataStore defaultStore];
  NSString *usedGroupIdentifier = ri.primaryGroupIdentifier;
  NSUInteger usedBatchLimit = ri.defaultBatchSize;
	
	if (!usedGroupIdentifier) {
		completionBlock(NO, nil, nil, [NSError errorWithDomain:@"com.waveface.wammer.dataStore.article" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Article sync requires a primary group identifier", NSLocalizedDescriptionKey,
		nil]]);
		return;
	}
  
  if ([syncStrategy isEqual:kWAArticleSyncMergeLastBatchStrategy]) {
  
    //  Merging the last batch only, don’t care about the vaccum at all — this is less expensive but has the potential to leave lots of vacuum in the application
    
    [ri retrieveLatestPostsInGroup:usedGroupIdentifier withBatchLimit:usedBatchLimit onSuccess:^(NSArray *postReps) {
    
      NSManagedObjectContext *context = [ds disposableMOC];
      context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;

      NSArray *touchedObjects = [[self class] insertOrUpdateObjectsUsingContext:context withRemoteResponse:postReps usingMapping:nil options:IRManagedObjectOptionIndividualOperations];

			NSError *savingError = nil;
			if ([context save:&savingError])
				NSLog(@"Error saving: %@", savingError);
							
      if (completionBlock)
        completionBlock(YES, context, touchedObjects, nil);
      
    } onFailure:^(NSError *error) {
    
      if (completionBlock)
        completionBlock(NO, nil, nil, error);
    
    }];
    
  } else if ([syncStrategy isEqual:kWAArticleSyncFullyFetchOnlyStrategy]) {
	
    NSMutableDictionary *sessionInfo = [options objectForKey:kWAArticleSyncSessionInfo];
    
    if (!sessionInfo)
      sessionInfo = [NSMutableDictionary dictionary];
      
    NSMutableDictionary *optionsContinuation = [options mutableCopy];
    [optionsContinuation setObject:sessionInfo forKey:kWAArticleSyncSessionInfo];
    
    dispatch_queue_t sessionQueue = ((^ {
      
      dispatch_queue_t returnedQueue = [[sessionInfo objectForKey:@"sessionQueue"] pointerValue];
      if (!returnedQueue) {
        returnedQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.%@.temporaryQueue",NSStringFromClass([self class]), NSStringFromSelector(_cmd)] UTF8String], DISPATCH_QUEUE_SERIAL);
        [sessionInfo setObject:[NSValue valueWithPointer:returnedQueue] forKey:@"sessionQueue"];
      }
      
      return returnedQueue;
      
    })());
    
    dispatch_async(sessionQueue, ^{
		
			NSString * const kObjectURIs = @"objectURIs";
    
			NSMutableArray *objectURIs = [sessionInfo objectForKey:kObjectURIs];
      
      if (!objectURIs) {
        objectURIs = [NSMutableArray array];
				[sessionInfo setObject:objectURIs forKey:kObjectURIs];
      }
			
      [ds fetchLatestArticleInGroup:usedGroupIdentifier onSuccess:^(NSString *identifier, WAArticle *article) {
			
        NSString *referencedPostIdentifier = identifier;
        NSDate *referencedPostDate = identifier ? nil : [NSDate distantPast];
        
        if (article.timestamp) {
          referencedPostDate = article.timestamp;
          referencedPostIdentifier = nil;
        }
				
        [ri retrievePostsInGroup:usedGroupIdentifier relativeToPost:referencedPostIdentifier date:referencedPostDate withSearchLimits:usedBatchLimit filter:nil onSuccess:^(NSArray *postReps) {
				
          dispatch_async(sessionQueue, ^ {
					
						__block BOOL shouldContinue = NO;
						
						[postReps enumerateObjectsUsingBlock: ^ (NSDictionary *aPost, NSUInteger idx, BOOL *stop) {
							
							if (![[aPost valueForKeyPath:@"post_id"] isEqual:identifier]) {
								shouldContinue = YES;
								*stop = YES;
							}
							
						}];
						
            if (shouldContinue) {
						
							NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
							context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
						
							NSArray *touchedObjects = [[self class] insertOrUpdateObjectsUsingContext:context withRemoteResponse:postReps usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
							
							NSError *savingError = nil;
							if ([context save:&savingError]) {
							
								[objectURIs addObjectsFromArray:[touchedObjects irMap: ^ (NSManagedObject *obj, NSUInteger index, BOOL *stop) {
									
									return [[obj objectID] URIRepresentation];
									
								}]];
								
								dispatch_async(dispatch_get_main_queue(), ^{
									
									[self synchronizeWithOptions:optionsContinuation completion:completionBlock];
									
								});

							} else {
							
								if (completionBlock)
									completionBlock(NO, context, objectURIs, savingError);
							
							}
							              
            } else {
						
							NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
							NSArray *savedObjects = [objectURIs irMap: ^ (NSURL *anObjectURI, NSUInteger index, BOOL *stop) {
								
								return [context irManagedObjectForURI:anObjectURI];
								
							}];
							
              if (completionBlock)
                completionBlock(YES, context, savedObjects, nil);
              
              dispatch_release(sessionQueue);
							
						}
            
          });
        
        } onFailure:^(NSError *error) {
				
          if (completionBlock)
            completionBlock(NO, nil, nil, error);
            
          dispatch_release(sessionQueue);
          
        }];

      }];
      
    });
      
  } else {
  
    NSParameterAssert(NO);
  
  }
  
}

- (void) synchronizeWithCompletion:(WAEntitySyncCallback)completionBlock {

  [self synchronizeWithOptions:nil completion:completionBlock];

}

- (void) synchronizeWithOptions:(NSDictionary *)options completion:(WAEntitySyncCallback)completionBlock {

	WARemoteInterface *ri = [WARemoteInterface sharedInterface];
	
	if ([self.draft isEqualToNumber:(id)kCFBooleanTrue] || !self.identifier) {
	
		NSURL *ownURL = [[self objectID] URIRepresentation];
	
		__block NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
		__block NSMutableDictionary *resultsDictionary = [NSMutableDictionary dictionary];
		
		if (self.text)
			[resultsDictionary setObject:self.text forKey:@"postText"];
		
		if (self.group.identifier)
			[resultsDictionary setObject:self.group.identifier forKey:@"postGroupIdentifier"];
		else
			[resultsDictionary setObject:ri.primaryGroupIdentifier forKey:@"postGroupIdentifier"];
		
		void (^cleanup)() = ^ {
			//	?
		};
		
		[operationQueue setSuspended:YES];
		
		operationQueue.maxConcurrentOperationCount = 1;
		
		BOOL (^dependentOperationCancelledOrFailed)(IRAsyncOperation *) = ^ (IRAsyncOperation *self) {
			
			for (IRAsyncOperation *op in self.dependencies)
			if ([op isCancelled] || ([op isFinished] && (!op.results || [op.results isKindOfClass:[NSError class]])))
				return YES;
			
			return NO;
			
		};
		
		NSError *dependentOperationCancelledOrFailedError = WAArticleEntitySyncingError(0, @"ARTICLE_SYNC_ERROR_DEPENDENT_OPERATION_FAILED_TITLE", @"ARTICLE_SYNC_ERROR_DEPENDENT_OPERATION_FAILED_DESCRIPTION");
	
		WAPreview *aPreview = [self.previews anyObject];
		NSURL *previewURL = [NSURL URLWithString:(aPreview.graphElement.url ? aPreview.graphElement.url : aPreview.url)];
		
		if (previewURL) {
		
			NSString *primaryImageURL = aPreview.graphElement.primaryImage.imageRemoteURL;
			if (primaryImageURL)
				[resultsDictionary setObject:primaryImageURL forKey:@"previewImageURL"];
			
			__block IRAsyncOperation *nrPreviewOp = [IRAsyncOperation operationWithWorkerBlock: ^ (void(^aCallback)(id results)) {
			
				if (dependentOperationCancelledOrFailed(nrPreviewOp)) {
					aCallback(dependentOperationCancelledOrFailedError);
					return;
				}
			
				[ri retrievePreviewForURL:previewURL onSuccess:^(NSDictionary *aPreviewRep) {
				
					aCallback(aPreviewRep);
					
				} onFailure: ^ (NSError *error) {
				
					aCallback(error);
					
				}];
				
			} completionBlock: ^ (id results) {
			
				if ([results isKindOfClass:[NSError class]])
					return;
				
				[resultsDictionary setObject:results forKey:@"previewEntity"];
				
			}];
			
			[operationQueue addOperation:nrPreviewOp];
		
		}
		
		[self.fileOrder enumerateObjectsUsingBlock: ^ (NSURL *aFileURL, NSUInteger idx, BOOL *stop) {
		
			WAFile *representedFile = (WAFile *)[self.managedObjectContext irManagedObjectForURI:aFileURL];
			if (!representedFile)
				return;
			
			[representedFile resourceURL];
			
			__block IRAsyncOperation *nrFileOperation = [IRAsyncOperation operationWithWorkerBlock: ^ (void(^aCallback)(id results)) {
				
				if (dependentOperationCancelledOrFailed(nrFileOperation)) {
					aCallback(dependentOperationCancelledOrFailedError);
					return;
				}
				
				[representedFile synchronizeWithCompletion:^(BOOL didFinish, NSManagedObjectContext *context, NSArray *objects, NSError *error) {
					
					if (!didFinish) {
						
						aCallback(error);

					} else {
				
						NSCParameterAssert([objects count] == 1);
						WAFile *savedFile = (WAFile *)[objects lastObject];
						
						NSCParameterAssert(savedFile.article);
						aCallback(savedFile.identifier);
					
					}
					
				}];
				
			} completionBlock:^(id results) {
			
				if ([results isKindOfClass:[NSError class]])
					return;
			
				NSMutableArray *fileIdentifiers = [resultsDictionary objectForKey:@"fileIdentifiers"];
				if (!fileIdentifiers) {
					fileIdentifiers = [NSMutableArray array];
					[resultsDictionary setObject:fileIdentifiers forKey:@"fileIdentifiers"];
				}
				
				[fileIdentifiers addObject:results];
			
			}];
			
			[operationQueue addOperation:nrFileOperation];
			
		}];
		
		__block IRAsyncOperation *nrFinalOperation = [IRAsyncOperation operationWithWorkerBlock: ^ (void(^aCallback)(id results)) {
		
			if (dependentOperationCancelledOrFailed(nrFinalOperation)) {
			
				for (IRAsyncOperation *dependentOp in nrFinalOperation.dependencies) {
					if ([dependentOp.results isKindOfClass:[NSError class]]) {
					
						aCallback((NSError *)dependentOp.results);
						return;
					}
				}
			
				aCallback(dependentOperationCancelledOrFailedError);
				return;
				
			}
		
			NSString *postGroupIdentifier = [resultsDictionary objectForKey:@"postGroupIdentifier"];
			NSString *postText = [resultsDictionary objectForKey:@"postText"];
			NSArray *attachmentIdentifiers = [resultsDictionary objectForKey:@"fileIdentifiers"];
			NSMutableDictionary *previewEntity = [[resultsDictionary objectForKey:@"previewEntity"] mutableCopy];
			NSString *previewImageURL = [resultsDictionary objectForKey:@"previewImageURL"];
			
			if (previewEntity && previewImageURL)
				[previewEntity setObject:previewImageURL forKey:@"thumbnail_url"];
			
			[ri createPostInGroup:postGroupIdentifier withContentText:postText attachments:attachmentIdentifiers preview:previewEntity onSuccess:^(NSDictionary *postRep) {
				
				aCallback(postRep);
				
			} onFailure: ^ (NSError *error) {
			
				aCallback(error);
				
			}];
			
		} completionBlock: ^ (id results) {
		
			if ([results isKindOfClass:[NSDictionary class]]) {
			
				NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
				context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
				
				WAArticle *savedPost = (WAArticle *)[context irManagedObjectForURI:ownURL];
				savedPost.draft = (id)kCFBooleanFalse;
				
				NSParameterAssert([[results valueForKeyPath:@"attachments"] count] == [savedPost.files count]);
				
				//	This would recursively delete the files too
				NSArray *oldFileOrder = [savedPost.fileOrder copy];
				NSSet *oldFiles = [savedPost.files copy];
				
				NSArray *touchedObjects = [WAArticle insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:results] usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
				
				NSParameterAssert([touchedObjects count]);
				
				WAArticle *recreatedPost = (WAArticle *)[touchedObjects lastObject];
				NSMutableSet *allInsertedFiles = [oldFiles mutableCopy];
				for (NSURL *anObjectURL in oldFileOrder) {
					
					NSArray *matchingFiles = [[allInsertedFiles objectsPassingTest: ^ (NSManagedObject *aFile, BOOL *stop) {
						return [[[aFile objectID] URIRepresentation] isEqual:anObjectURL];
					}] allObjects];
					
					for (id anInsertedFile in matchingFiles)
						[allInsertedFiles removeObject:anInsertedFile];
					
					[recreatedPost addFilesObject:[matchingFiles lastObject]];
					
				}
				
				NSParameterAssert([recreatedPost.files count] == [recreatedPost.fileOrder count]);
				for (WAFile *aFile in recreatedPost.files)
					NSParameterAssert(aFile.article == recreatedPost);
				
				NSParameterAssert(![savedPost.files count]);
				
				[context deleteObject:savedPost];
				
				NSError *savingError = nil;
				BOOL didSave = [context save:&savingError];
				
				completionBlock(didSave, context, [NSArray arrayWithObject:savedPost], didSave ? nil : savingError);
			
			} else {
			
				completionBlock(NO, nil, nil, results);
			
			}
		
			dispatch_async(dispatch_get_main_queue(), ^ {
				cleanup();
			});
			
		}];
		
		NSArray *allOps = operationQueue.operations;
		[allOps enumerateObjectsUsingBlock: ^ (NSOperation *anOperation, NSUInteger idx, BOOL *stop) {
		
			if (idx != 0)
				[anOperation addDependency:[allOps objectAtIndex:(idx - 1)]];

			[nrFinalOperation addDependency:anOperation];
			
		}];
		
		[operationQueue addOperation:nrFinalOperation];
		[operationQueue setSuspended:NO];
	
	} else {
	
		[ri retrievePost:self.identifier inGroup:self.group.identifier onSuccess:^(NSDictionary *postRep) {
		
			if (!completionBlock)
				return;
			
			NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
			context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
			
			NSArray *touchedObjects = [[self class] insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:postRep] usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
			
			WAArticle *savedPost = (WAArticle *)[touchedObjects lastObject];
			savedPost.draft = (id)kCFBooleanFalse;
			
			NSError *savingError = nil;
			BOOL didSave = [context save:&savingError];
			
			completionBlock(didSave, context, [NSArray arrayWithObject:savedPost], didSave ? nil : savingError);	
			
		} onFailure:^(NSError *error) {
		
			if (!completionBlock)
				return;
				
			completionBlock(NO, nil, nil, error);
			
		}];
	
	}

}

@end
