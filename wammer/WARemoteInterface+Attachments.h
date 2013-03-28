//
//  WARemoteInterface+Attachments.h
//  wammer
//
//  Created by Evadne Wu on 11/8/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "WARemoteInterface.h"

#ifndef __WARemoteInterface_Attachments__
#define __WARemoteInterface_Attachments__

enum  {
  WARemoteAttachmentUnknownType = 0,
  WARemoteAttachmentImageType = 1,
	WARemoteAttachmentDocumentType = 2
}; typedef NSUInteger WARemoteAttachmentType;

#endif


extern NSString * const kWARemoteAttachmentType;
extern NSString * const kWARemoteAttachmentTitle;
extern NSString * const kWARemoteAttachmentDescription;
extern NSString * const kWARemoteAttachmentRepresentingImageURL;
extern NSString * const kWARemoteAttachmentUpdatedObjectIdentifier;


//	kWARemoteAttachmentSubtype should be specified for WARemoteAttachmentImageType
//	otherwise the default is WARemoteAttachmentOriginalSubtype (as-is)

extern NSString * const kWARemoteAttachmentSubtype;

extern NSString * const kWARemoteArticleIdentifier;
extern NSString * const kWARemoteAttachmentFileName;
extern NSString * const kWARemoteAttachmentExifId;
extern NSString * const kWARemoteAttachmentCreateTime;
extern NSString * const kWARemoteAttachmentImportTime;

//	Maps to remote values

extern NSString * const WARemoteAttachmentOriginalSubtype;
extern NSString * const WARemoteAttachmentLargeSubtype;
extern NSString * const WARemoteAttachmentMediumSubtype;
extern NSString * const WARemoteAttachmentSmallSubtype;

typedef NSString * const WARemoteAttachmentSubtype;


@interface WARemoteInterface (Attachments)

//	POST attachments/upload
- (void) createAttachmentWithFile:(NSURL *)aFileURL group:(NSString *)aGroupIdentifier options:(NSDictionary *)options onSuccess:(void(^)(NSString *attachmentIdentifier))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET attachments/get
- (void) retrieveAttachment:(NSString *)anIdentifier onSuccess:(void(^)(NSDictionary *attachmentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST attachments/delete
- (void) deleteAttachments:(NSArray *)identifiers onSuccess:(void(^)(NSArray *successIDs, NSArray *failureIDs))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	GET attachments/view
- (void) retrieveThumbnailForAttachment:(NSString *)anIdentifier ofType:(WARemoteAttachmentType)aType onSuccess:(void(^)(NSURL *aThumbnailURL))successBlock onFailure:(void(^)(NSError *error))failureBlock;

- (void) createAttachmentWithFileAtURL:(NSURL *)aFileURL inGroup:(NSString *)aGroupIdentifier representingImageURL:(NSURL *)aRepresentingImageForBinaryTypesOrNil withTitle:(NSString *)aTitle description:(NSString *)aDescription replacingAttachment:(NSString *)replacedAttachmentIdentifierOrNil asType:(WARemoteAttachmentType)aType onSuccess:(void(^)(NSString *attachmentIdentifier))successBlock onFailure:(void(^)(NSError *error))failureBlock DEPRECATED_ATTRIBUTE;

// POST attachments/upload_metadata
- (void) createAttachmentMetas:(NSArray *)metas onSuccess:(void(^)(NSArray *successIDs))successBlock onFailure:(void(^)(NSError *error))failureBlock;

// POST attachments/multiple_get
- (void) retrieveMetaForAttachments:(NSArray *)identifiers onSuccess:(void(^)(NSArray *attachmentReps, NSArray *successList, NSArray *failureList))successBlock onFailure:(void(^)(NSError *error))failureBlock;

// POST attachments/hide
- (void) hideAttachments:(NSArray *)identifiers onSuccess:(void(^)(NSArray *successIDs))successBlock onFailure:(void(^)(NSError *error))failureBlock;

@end
