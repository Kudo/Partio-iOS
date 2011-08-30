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

@property (nonatomic, readwrite, retain) NSString *userIdentifier;
@property (nonatomic, readwrite, retain) NSString *userToken;

- (void) retrieveTokenForUserWithIdentifier:(NSString *)anIdentifier password:(NSString *)aPassword onSuccess:(void(^)(NSDictionary *userRep, NSString *token))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /users
- (void) retrieveAvailableUsersOnSuccess:(void(^)(NSArray *retrievedUserReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /articles
- (void) retrieveArticlesWithContinuation:(id)aContinuation batchLimit:(NSUInteger)maximumNumberOfArticles onSuccess:(void(^)(NSArray *retrievedArticleReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /article/#
- (void) retrieveArticleWithRemoteIdentifier:(NSString *)anIdentifier onSuccess:(void(^)(NSDictionary *retrievedArticleRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET /article/#/comments
- (void) retrieveCommentsOfArticleWithRemoteIdentifier:(NSString *)anIdentifier onSuccess:(void(^)(NSArray *retrievedComentReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST /article
- (void) createArticleAsUser:(NSString *)creatorIdentifier withText:(NSString *)bodyText attachments:(NSArray *)attachmentIdentifiers usingDevice:(NSString *)creationDeviceName onSuccess:(void(^)(NSDictionary *createdCommentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST /file
- (void) uploadFileAtURL:(NSURL *)aFileURL asUser:(NSString *)creatorIdentifier onSuccess:(void(^)(NSDictionary *uploadedFileRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST /comment
- (void) createCommentAsUser:(NSString *)creatorIdentifier forArticle:(NSString *)anIdentifier withText:(NSString *)bodyText usingDevice:(NSString *)creationDeviceName onSuccess:(void(^)(NSDictionary *createdCommentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

@end





@interface WADataStore (WARemoteInterfaceAdditions)

- (void) updateUsersOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock;
- (void) updateArticlesOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock;
- (void) uploadArticle:(NSURL *)anArticleURI onSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock;

- (void) updateUsersWithCompletion:(void(^)(void))aBlock DEPRECATED_ATTRIBUTE;
- (void) updateArticlesWithCompletion:(void(^)(void))aBlock DEPRECATED_ATTRIBUTE;
- (void) uploadArticle:(NSURL *)anArticleURI withCompletion:(void(^)(void))aBlock DEPRECATED_ATTRIBUTE;

@end
