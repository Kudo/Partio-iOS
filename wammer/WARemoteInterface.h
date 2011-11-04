//
//  WARemoteInterface.h
//  wammer-iOS
//
//  Created by Evadne Wu on 7/21/11.
//  Copyright 2011 Waveface. All rights reserved.
//
//  https://gist.github.com/46e424e637d6634979d3

#include <AvailabilityMacros.h>

#import "IRWebAPIKit.h"
#import "WADataStore.h"

@interface WARemoteInterface : IRWebAPIInterface

+ (WARemoteInterface *) sharedInterface;

# pragma mark - Configuration

@property (nonatomic, readwrite, assign) NSUInteger defaultBatchSize;


# pragma mark - Identity

@property (nonatomic, readwrite, retain) NSString *userIdentifier;
@property (nonatomic, readwrite, retain) NSString *userToken;

- (void) retrieveTokenForUserWithIdentifier:(NSString *)anIdentifier password:(NSString *)aPassword onSuccess:(void(^)(NSDictionary *userRep, NSString *token))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Users

//	GET /users
- (void) retrieveAvailableUsersOnSuccess:(void(^)(NSArray *retrievedUserReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Articles

//	GET /articles
- (void) retrieveArticlesWithContinuation:(id)aContinuation batchLimit:(NSUInteger)maximumNumberOfArticles onSuccess:(void(^)(NSArray *retrievedArticleReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /article/#
- (void) retrieveArticleWithRemoteIdentifier:(NSString *)anIdentifier onSuccess:(void(^)(NSDictionary *retrievedArticleRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /article/#/comments
- (void) retrieveCommentsOfArticleWithRemoteIdentifier:(NSString *)anIdentifier onSuccess:(void(^)(NSArray *retrievedComentReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST /article
- (void) createArticleAsUser:(NSString *)creatorIdentifier withText:(NSString *)bodyText attachments:(NSArray *)attachmentIdentifiers usingDevice:(NSString *)creationDeviceName onSuccess:(void(^)(NSDictionary *createdCommentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Files

//	POST /file
- (void) uploadFileAtURL:(NSURL *)aFileURL asUser:(NSString *)creatorIdentifier onSuccess:(void(^)(NSDictionary *uploadedFileRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Comments

//	POST /comment
- (void) createCommentAsUser:(NSString *)creatorIdentifier forArticle:(NSString *)anIdentifier withText:(NSString *)bodyText usingDevice:(NSString *)creationDeviceName onSuccess:(void(^)(NSDictionary *createdCommentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Progress Sync

//	GET users/latest_read_post_id
- (void) retrieveLastReadArticleRemoteIdentifierOnSuccess:(void(^)(NSString *lastID, NSDate *modDate))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST users/latest_read_post_id
- (void) setLastReadArticleRemoteIdentifier:(NSString *)anIdentifier onSuccess:(void(^)(NSDictionary *response))successBlock onFailure:(void(^)(NSError *error))failureBlock;


# pragma mark - Scheduled Data Retrieval

//	The data retrieval is usually scheduled every 30 seconds, described by the dataRetrievalInterval property.  If any remote operation began, and it will eventually load data that will also be loaded by the data retrieval blocks, call -rescheduleNextAutomaticDataRetrieval frequently to block automatic data retrieval.  Blocking auto data retrieval during manual / other implicit remote data loading avoids wasting time working on local store merging.

- (void) beginPostponingDataRetrievalTimerFiring;
- (void) endPostponingDataRetrievalTimerFiring;
- (BOOL) isPostponingDataRetrievalTimerFiring;

- (void) rescheduleAutomaticRemoteUpdates;
- (void) performAutomaticRemoteUpdatesNow;	// Also reschedules, great for manual refreshing

- (void) beginPerformingAutomaticRemoteUpdates;
- (void) endPerformingAutomaticRemoteUpdates;
- (BOOL) isPerformingAutomaticRemoteUpdates;

@property (nonatomic, readonly, assign, getter=isPerformingAutomaticRemoteUpdates) BOOL performingAutomaticRemoteUpdates;	//	KVO-able for manual refreshing buttons

@property (nonatomic, readwrite, assign) NSTimeInterval dataRetrievalInterval;
@property (nonatomic, readonly, retain) NSDate *nextRemoteDataRetrievalFireDate;

@property (nonatomic, readonly, retain) NSArray *dataRetrievalBlocks;
- (NSArray *) defaultDataRetrievalBlocks;
- (void) addRepeatingDataRetrievalBlock:(void(^)(void))aBlock;
- (void) addRepeatingDataRetrievalBlocks:(NSArray *)blocks;

@end
