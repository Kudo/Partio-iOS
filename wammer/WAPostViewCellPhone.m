//
//  WAArticleCommentsViewCell.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/12/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAPostViewCellPhone.h"

#import "UIKit+IRAdditions.h"
#import "QuartzCore+IRAdditions.h"

#import "WADefines.h"
#import "WAImageStackView.h"
#import "WAPreviewBadge.h"


@interface WAPostViewCellPhone () <IRTableViewCellPrototype>

@end


@implementation WAPostViewCellPhone

@synthesize backgroundImageView;
@synthesize monthLabel, dayLabel;
@synthesize extraInfoLabel;
@synthesize contentTextView;
@synthesize commentLabel;
@synthesize imageStackView, avatarView, userNicknameLabel, contentDescriptionLabel, dateOriginLabel, dateLabel, originLabel;
@synthesize previewBadge, previewImageView, previewTitleLabel, previewProviderLabel, previewImageBackground;

+ (NSSet *) encodedObjectKeyPaths {

	return [NSSet setWithObjects:@"backgroundImageView", @"monthLabel", @"dayLabel", @"extraInfoLabel", @"contentTextView", @"commentLabel", @"imageStackView", @"avatarView", @"userNicknameLabel", @"contentDescriptionLabel", @"dateOriginLabel", @"dateLabel", @"originLabel", @"previewBadge", @"previewImageView", @"previewTitleLabel", @"previewProviderLabel", @"previewImageBackground", nil];

}

+ (NSSet *) keyPathsForValuesAffectingArticle {

	return [NSSet setWithObjects:
		
		@"representedObject",
		
	nil];

}

- (WAArticle *) article {

	return (WAArticle *)self.representedObject;

}

+ (WAPostViewCellPhone *) newPrototypeForIdentifier:(NSString *)identifier {

	WAPostViewCellPhone *cell = nil;

	if ([identifier isEqualToString:@"PostCell-Stacked"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	} else if ([identifier isEqualToString:@"PostCell-WebLink"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLink" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	} else if ([identifier isEqualToString:@"PostCell-WebLinkNoPhoto"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLink" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:1];
	
	} else if ([identifier isEqualToString:@"PostCell-TextOnly"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-Default" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	}
	
	cell.selectedBackgroundView = ((^ {
	
		UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
		view.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
		view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
		return view;
		
	})());
	
	cell.previewBadge.titleFont = [UIFont systemFontOfSize:14.0f];
	cell.previewBadge.textFont = [UIFont systemFontOfSize:14.0f];
	
	return cell;

}

+ (NSString *) identifierRepresentingObject:(WAArticle *)article {

	if (!![article.files count])
		return @"PostCell-Stacked";
	
	if (!![article.previews count])
		return (((WAPreview *)[article.previews anyObject]).thumbnail) ? @"PostCell-WebLink" : @"PostCell-WebLinkNoPhoto";
	
	return @"PostCell-TextOnly";

}

- (CGFloat) heightForRowRepresentingObject:(WAArticle *)object inTableView:(UITableView *)tableView {

//	BOOL isWebPost = !![object.previews count];
//	BOOL isPhotoPost = !![object.files count];
//	if (isWebPost)
//		return 158;
	
	NSString *identifier = [[self class] identifierRepresentingObject:object];
	WAPostViewCellPhone *prototype = (WAPostViewCellPhone *)[[self class] prototypeForIdentifier:identifier];
	NSParameterAssert([prototype isKindOfClass:[WAPostViewCellPhone class]]);
	prototype.frame = (CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(tableView.bounds),
			CGRectGetHeight(prototype.bounds)
		}
	};
	
	CGRect oldLabelFrame = prototype.commentLabel.frame;
	CGFloat cellLabelHeightDelta = CGRectGetHeight(prototype.bounds) - CGRectGetHeight(oldLabelFrame);
	
	prototype.commentLabel.frame = (CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(prototype.commentLabel.bounds),
			0
		}
	};
	
	prototype.commentLabel.text = object.text;
	
	[prototype.commentLabel sizeToFit];
	
	CGFloat answer = roundf(MIN(prototype.commentLabel.font.leading * 3, CGRectGetHeight(prototype.commentLabel.bounds)) + cellLabelHeightDelta);
	prototype.commentLabel.frame = oldLabelFrame;
	
	return MAX(answer, CGRectGetHeight(prototype.bounds));
	
}

- (void) setRepresentedObject:(id)representedObject {

	[super setRepresentedObject:representedObject];
	
	WAArticle *post = representedObject;
	NSParameterAssert([post isKindOfClass:[WAArticle class]]);

	BOOL postHasFiles = (BOOL)!![post.files count];
	BOOL postHasPreview = (BOOL)!![post.previews count];
	
	NSDate *postDate = post.presentationDate;
	NSString *relativeDateString = [[IRRelativeDateFormatter sharedFormatter] stringFromDate:postDate];
	
	self.originLabel.text = [NSString stringWithFormat:@"%@ from %@",
		relativeDateString,
		post.creationDeviceName
	];
	
	self.dateLabel.text = [relativeDateString lowercaseString];
	self.commentLabel.text = ([post.text length]>0)? post.text : @"My life is a tapestry for rich and royal you.";
	
	if (postHasPreview) {

		WAPreview *preview = [post.previews anyObject];
		
		self.extraInfoLabel.text = @"";
	 
		self.previewBadge.preview = preview;
		
		self.accessibilityLabel = @"Preview";
		self.accessibilityHint = preview.graphElement.title;
		self.accessibilityValue = preview.graphElement.text;
		
		self.previewImageView.image = preview.thumbnail;
		self.previewTitleLabel.text = preview.graphElement.title;
		self.previewProviderLabel.text = preview.graphElement.providerDisplayName;
			
	} else if (postHasFiles) {

		self.accessibilityValue = post.text;
		
		NSArray *allFileURIs = post.fileOrder;
		NSMutableArray *usedFileURIs = [[allFileURIs subarrayWithRange:(NSRange){ 0, MIN(3, [allFileURIs count])}] mutableCopy];
		
		NSURL *representingFileURI = [[post.representingFile objectID] URIRepresentation];
		
		if ([usedFileURIs containsObject:representingFileURI])
			[usedFileURIs removeObject:representingFileURI];
		
		[usedFileURIs insertObject:representingFileURI atIndex:0];
		
		NSArray *imagesForTimeline = [usedFileURIs irMap:^(NSURL *fileURI, NSUInteger index, BOOL *stop) {
			
			if (index > 2) {
				*stop = YES;
				return (id)nil;
			}
			
			WAFile *file = (WAFile *)[post.managedObjectContext irManagedObjectForURI:fileURI];
			return (id)file.thumbnailImage;
			
		}];
		
		[self.imageStackView setImages:imagesForTimeline asynchronously:YES withDecodingCompletion:nil];
		
		if ([post.files count] > 3) {
			self.extraInfoLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUMBER_OF_PHOTOS", @"Photo information in cell"), [post.files count]];
		}
	
		self.accessibilityLabel = @"Photo";
		
		NSString *photoInfo = @"%d photos ";
		if ( [post.files count]==1 )
			photoInfo = @"%d photo ";
		self.accessibilityHint = [NSString stringWithFormat:photoInfo, [post.files count]];
		self.originLabel.text = [self.accessibilityHint stringByAppendingString:self.originLabel.text];
		
  } else {
		
		self.commentLabel.text = post.text;
		self.extraInfoLabel.text = @"";
	 
		self.accessibilityLabel = @"Text Post";
		self.accessibilityValue = post.text;
		
	}
		
	self.commentLabel.text = post.text;
	
	UIColor *textColor;
	UIColor *shadowColor;

	if ([post.favorite isEqual:(id)kCFBooleanTrue]) {
		self.backgroundImageView.image = [UIImage imageNamed:@"tagFavorite"];
		textColor = [UIColor whiteColor];
		shadowColor = [UIColor colorWithHue:155/360 saturation:0.0 brightness:0.8 alpha:1.0];
	} else {
		self.backgroundImageView.image = [UIImage imageNamed:@"tagDefault"];
		textColor = [UIColor colorWithHue:111/360 saturation:0.0 brightness:0.56 alpha:1.0];
		shadowColor = [UIColor colorWithHue:111/360 saturation:0.0 brightness:1.0 alpha:1.0];
		
	} 
	
	self.dayLabel.textColor = textColor;
	self.dayLabel.shadowColor = shadowColor;
	self.monthLabel.textColor = textColor;
	self.monthLabel.shadowColor = shadowColor;
	
	//	TBD: optimize if slow
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	
	dateFormatter.dateFormat = @"dd";
	self.dayLabel.text = [dateFormatter stringFromDate:postDate];
	
	dateFormatter.dateFormat = @"MMM";
	self.monthLabel.text = [[dateFormatter stringFromDate:postDate] uppercaseString];
	
	[self setNeedsLayout];
	
}

@end
