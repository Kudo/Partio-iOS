//
//  WADataStore+WARemoteInterfaceAdditions.m
//  wammer
//
//  Created by Evadne Wu on 11/4/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WADefines.h"
#import "WARemoteInterface.h"

#import "WADataStore+WARemoteInterfaceAdditions.h"
#import "WAOverlayBezel.h"


NSString * const kWADataStoreArticleUpdateShowsBezels = @"WADataStoreArticleUpdateShowsBezels";
NSString * const kWADataStoreArticleUpdateVisibilityOnly = @"WADataStoreArticleUpdateVisibilityOnly";


@interface WADataStore (WARemoteInterfaceAdditions_Private)

- (NSMutableSet *) articlesCurrentlyBeingUpdated;

@end


@implementation WADataStore (WARemoteInterfaceAdditions)

- (BOOL) hasDraftArticles {

  NSManagedObjectContext *context = [self disposableMOC];
 
  NSFetchRequest *fr = [[self managedObjectModel] fetchRequestTemplateForName:@"WAFRArticleDrafts"];
  
  NSError *fetchingError = nil;
  NSArray *fetchedDrafts = [context executeFetchRequest:fr error:&fetchingError];
  
  if (!fetchedDrafts)
    NSLog(@"Error fetching: %@", fetchingError);
  
  return (BOOL)!![fetchedDrafts count];

}

- (void) updateArticlesWithCompletion:(void(^)(NSError *))aBlock {

	[self updateArticlesOnSuccess: ^ {
	
		if (aBlock)
			aBlock(nil);
	
	} onFailure:aBlock];

}

- (void) updateArticlesOnSuccess:(void (^)(void))successBlock onFailure:(void (^)(NSError *error))failureBlock {

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		
		kWAArticleSyncDefaultStrategy, kWAArticleSyncStrategy,
		
	nil];
	
	[WAArticle synchronizeWithOptions:options completion:^(BOOL didFinish, NSManagedObjectContext *temporalContext, NSArray *prospectiveUnsavedObjects, NSError *anError) {
	
		if (didFinish) {

			if (successBlock)
				successBlock();
			
		} else {
		
			if (failureBlock)
				failureBlock(anError);
		
		}
		
	}];
	
}

- (void) uploadArticle:(NSURL *)anArticleURI withCompletion:(void(^)(NSError *))aBlock {

	[self updateArticle:anArticleURI onSuccess:^ {
	
		if (aBlock)
			aBlock(nil);
	
	} onFailure:aBlock];

}
          
- (void) updateArticle:(NSURL *)anArticleURI onSuccess:(void (^)(void))successBlock onFailure:(void (^)(NSError *error))failureBlock {

	[self updateArticle:anArticleURI withOptions:nil onSuccess:successBlock onFailure:failureBlock];

}

- (void) updateArticle:(NSURL *)anArticleURI withOptions:(NSDictionary *)options onSuccess:(void (^)(void))successBlock onFailure:(void (^)(NSError *error))failureBlock {

	NSParameterAssert([NSThread isMainThread]);
	
	BOOL usesBezels = [[options objectForKey:kWADataStoreArticleUpdateShowsBezels] isEqual:(id)kCFBooleanTrue];
	
	BOOL updateVisibilityOnly = [[options objectForKey:kWADataStoreArticleUpdateVisibilityOnly] isEqual:(id)kCFBooleanTrue];

	__weak WADataStore *wSelf = self;
	
	NSManagedObjectContext *context = [self defaultAutoUpdatedMOC];	//	Sigh
	WAArticle *article = (WAArticle *)[context irManagedObjectForURI:anArticleURI];
	
	[[wSelf articlesCurrentlyBeingUpdated] addObject:anArticleURI];
	
	WAOverlayBezel *busyBezel = nil;
	if (usesBezels) {
		busyBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
		[busyBezel showWithAnimation:WAOverlayBezelAnimationFade];
	}
	
	void (^fireCallback)(BOOL, NSError *) = ^ (BOOL didFinish, NSError *error) {
			
		NSCParameterAssert([NSThread isMainThread]);
	
		if (didFinish) {
			
			if (successBlock)
				successBlock();
		
		} else {

			if (failureBlock)
				failureBlock(error);
			
		}
		
		[[wSelf articlesCurrentlyBeingUpdated] removeObject:anArticleURI];
		
	};
	
	void (^handleResult)(BOOL, NSError *) = ^ (BOOL didFinish, NSError *error) {
		
		NSCParameterAssert([NSThread isMainThread]);
	
		if (usesBezels) {
			
			[busyBezel dismissWithAnimation:WAOverlayBezelAnimationNone];
			
			WAOverlayBezel *resultBezel = [WAOverlayBezel bezelWithStyle:(didFinish ? WACheckmarkBezelStyle : WAErrorBezelStyle)];
			[resultBezel showWithAnimation:WAOverlayBezelAnimationNone];
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
			
				[resultBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
				
				fireCallback(didFinish, error);
			
			});
			
		} else {
		
			fireCallback(didFinish, error);
		
		}
		
	};
	
	
	if (updateVisibilityOnly) {
	
		[[WARemoteInterface sharedInterface] configurePost:article.identifier inGroup:article.group.identifier withVisibilityStatus:![article.hidden isEqual:(id)kCFBooleanTrue] onSuccess:^{
		
			dispatch_async(dispatch_get_main_queue(), ^{
				handleResult(YES, nil);
			});
			
		} onFailure:^(NSError *error) {
		
			dispatch_async(dispatch_get_main_queue(), ^{
				handleResult(NO, error);
			});
			
		}];
	
	} else {
	
		[article synchronizeWithCompletion:^(BOOL didFinish, NSManagedObjectContext *context, NSArray *objects, NSError *error) {
			
			handleResult(didFinish, error);
					
		}];
		
	}
	
}

- (BOOL) isUpdatingArticle:(NSURL *)anObjectURI {

	return [[self articlesCurrentlyBeingUpdated] containsObject:anObjectURI];

}

- (void) addComment:(NSString *)commentText onArticle:(NSURL *)anArticleURI onSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock {
	
	NSManagedObjectContext *context = [self disposableMOC];
	WAArticle *updatedArticle = (WAArticle *)[context irManagedObjectForURI:anArticleURI];
	
	NSString *postIdentifier = updatedArticle.identifier;
	NSString *groupIdentifier = updatedArticle.group.identifier;
	
	if (!postIdentifier) {
		[NSException raise:NSInternalInconsistencyException format:@"Article %@ has not been saved, and was not assigned a remote identifier.", updatedArticle];
		return;
	}
	
	if (!groupIdentifier) {
		[NSException raise:NSInternalInconsistencyException format:@"Article %@ has not yet been assigned a group.", updatedArticle];
		return;
	}
	
	[[WARemoteInterface sharedInterface] createCommentForPost:postIdentifier inGroup:groupIdentifier withContentText:commentText onSuccess:^(NSDictionary *updatedPostRep) {
	
		NSManagedObjectContext *context = [self disposableMOC];
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
		
		[WAArticle insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:updatedPostRep] usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
		
		NSError *savingError = nil;
		if (![context save:&savingError])
			NSLog(@"Error Saving: %@", savingError);
		
		if (successBlock)
			successBlock();
		
	} onFailure:^(NSError *error) {
	
		if (failureBlock)
			failureBlock();
		
	}];

}

- (void) updateCurrentUserOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock {

	WARemoteInterface *ri = [WARemoteInterface sharedInterface];
	NSString *userIdentifier = ri.userIdentifier;
	NSParameterAssert(userIdentifier);
	
	__weak WADataStore *wSelf = self;
	
	[ri retrieveUser:userIdentifier onSuccess: ^ (NSDictionary *userRep) {
	
		dispatch_async(dispatch_get_main_queue(), ^ {
			
			NSManagedObjectContext *context = [wSelf disposableMOC];
			context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
			
			WAUser *user = [wSelf mainUserInContext:context];
			NSCParameterAssert(user);
			
			NSArray *touchedUsers = [WAUser insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:userRep] usingMapping:nil options:0];
			
			NSCParameterAssert([touchedUsers count] == 1);
			NSCParameterAssert([touchedUsers containsObject:user]);
			
			NSError *savingError = nil;
			if (![context save:&savingError])
				NSLog(@"%@: %@", NSStringFromSelector(_cmd), savingError);
			
			if (successBlock)
				successBlock();
			
		});
		
	} onFailure:^(NSError *error) {
			
		NSLog(@"%@: %@", NSStringFromSelector(_cmd), error);
		
		if (failureBlock)
			failureBlock();
		
	}];

}

@end


@implementation WADataStore (WARemoteInterfaceAdditions_Private)

- (NSMutableSet *) articlesCurrentlyBeingUpdated {

	static NSString * const key = @"WADataStore_WARemoteInterfaceAdditions_articlesCurrentlyBeingUploaded";
	
	NSMutableSet *returnedSet = objc_getAssociatedObject(self, &key);
	if (!returnedSet) {
		returnedSet = [NSMutableSet set];
		objc_setAssociatedObject(self, &key, returnedSet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return returnedSet;

}

@end
