//
//  WAFetchManager+RemoteArticleFetch.m
//  wammer
//
//  Created by kchiu on 12/12/27.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFetchManager+RemoteArticleFetch.h"
#import "Foundation+IRAdditions.h"
#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"
#import "WADefines.h"

@implementation WAFetchManager (RemoteArticleFetch)

- (IRAsyncOperation *)remoteArticleFetchOperationPrototype {

  __weak WAFetchManager *wSelf = self;

  IRAsyncOperation *operation = [IRAsyncOperation operationWithWorker:^(IRAsyncOperationCallback callback) {
    
    if (![wSelf canPerformArticleFetch]) {
      callback(nil);
      return;
    }

    [wSelf beginPostponingFetch];

    IRAsyncOperation *operation = [IRAsyncOperation operationWithWorker:^(IRAsyncOperationCallback callback) {

      WADataStore *ds = [WADataStore defaultStore];
      NSNumber *currentSeq = [ds minSequenceNumber];
      if (!currentSeq) {
        currentSeq = @(INT_MAX);
      }

      WARemoteInterface *ri = [WARemoteInterface sharedInterface];
      [ri retrievePostsInGroup:ri.primaryGroupIdentifier usingSequenceNumber:currentSeq withLimit:@(-100) onSuccess:^(NSArray *postReps, NSNumber *remainingCount, NSNumber*nextSeq) {

        [ds performBlock:^{
	
	NSManagedObjectContext *context = [ds autoUpdatingMOC];
	
	NSArray *touchedArticles = [WAArticle insertOrUpdateObjectsUsingContext:context withRemoteResponse:postReps usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
	
	// restore articles in updating
	for (WAArticle *article in touchedArticles) {
	  if ([ds isUpdatingArticle:[[article objectID] URIRepresentation]]) {
	    [context refreshObject:article mergeChanges:NO];
	  }
	}
	
	[context save:nil];
	
        } waitUntilDone:YES];
        
        if ([remainingCount integerValue] == 0) {
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAFirstArticleFetched];
	[[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        if (![ds maxSequenceNumber]) {
	if ([postReps count]) {
	  NSNumber *maxSeq = @0;
	  for (NSDictionary *post in postReps) {
	    if ([post[@"seq_num"] integerValue] > [maxSeq integerValue]) {
	      maxSeq = post[@"seq_num"];
	    }
	  }
	  [ds setMaxSequenceNumber:@([maxSeq integerValue]+1)];
	}
        }
        
        [ds setMinSequenceNumber:nextSeq];
        
        callback(nil);

      } onFailure:^(NSError *error) {

        callback(error);

      }];

    } trampoline:^(IRAsyncOperationInvoker callback) {

      NSCParameterAssert(![NSThread isMainThread]);
      callback();

    } callback:^(id results) {

      // NO OP

    } callbackTrampoline:^(IRAsyncOperationInvoker callback) {

      NSCParameterAssert(![NSThread isMainThread]);
      callback();

    }];

    [self.articleFetchOperationQueue addOperation:operation];

    NSOperation *tailOp = [NSBlockOperation blockOperationWithBlock:^{
      [wSelf endPostponingFetch];
      callback(nil);
    }];

    for (NSOperation *operation in [self.articleFetchOperationQueue operations]) {
      [tailOp addDependency:operation];
    }
    
    [self.articleFetchOperationQueue addOperation:tailOp];

  } trampoline:^(IRAsyncOperationInvoker callback) {

    NSCParameterAssert(![NSThread isMainThread]);
    callback();

  } callback:^(id results) {

    // NO OP

  } callbackTrampoline:^(IRAsyncOperationInvoker callback) {

    NSCParameterAssert(![NSThread isMainThread]);
    callback();

  }];

  return operation;

}

- (BOOL)canPerformArticleFetch {

  if (![WARemoteInterface sharedInterface].userToken) {
    return NO;
  }

  if ([[NSUserDefaults standardUserDefaults] boolForKey:kWAFirstArticleFetched]) {
    return NO;
  }

  return YES;

}

@end
