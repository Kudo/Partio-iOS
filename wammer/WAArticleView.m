//
//  WAArticleView.m
//  wammer-iOS
//
//  Created by Evadne Wu on 10/11/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticleView.h"
#import "WAImageStackView.h"
#import "WAPreviewBadge.h"
#import "WAArticleTextEmphasisLabel.h"
#import "WADataStore.h"

#import "IRRelativeDateFormatter.h"
#import "WAArticleViewController.h"

#import "IRLifetimeHelper.h"


@interface WAArticleView ()

- (void) waInit;
- (void) associateBindings;
- (void) disassociateBindings;

+ (IRRelativeDateFormatter *) relativeDateFormatter;

@property (nonatomic, readwrite, assign) WAArticleViewControllerPresentationStyle presentationStyle;

@end


@implementation WAArticleView

@synthesize article;

@synthesize presentationStyle;

@synthesize contextInfoContainer, imageStackView, previewBadge, textEmphasisView, avatarView, relativeCreationDateLabel, userNameLabel, articleDescriptionLabel, deviceDescriptionLabel, contextTextView, mainImageView;

- (id) initWithFrame:(CGRect)frame {

	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	
	[self waInit];
	
	return self;

}

- (void) awakeFromNib {

	[super awakeFromNib];
	
	[self waInit];

}

- (void) waInit {

	if (self.avatarView) {

		self.avatarView.layer.masksToBounds = YES;
		self.avatarView.backgroundColor = [UIColor colorWithRed:0.85f green:0.85f blue:0.85f alpha:1];
		UIView *avatarContainingView = [[[UIView alloc] initWithFrame:self.avatarView.frame] autorelease];
		avatarContainingView.autoresizingMask = self.avatarView.autoresizingMask;
		self.avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self.avatarView.superview insertSubview:avatarContainingView belowSubview:self.avatarView];
		[avatarContainingView addSubview:self.avatarView];
		self.avatarView.center = (CGPoint){ CGRectGetMidX(self.avatarView.superview.bounds), CGRectGetMidY(self.avatarView.superview.bounds) };
		//	avatarContainingView.layer.shadowPath = [UIBezierPath bezierPathWithRect:avatarContainingView.bounds].CGPath;
		//	avatarContainingView.layer.shadowOpacity = 0.25f;
		//	avatarContainingView.layer.shadowOffset = (CGSize){ 0, 1 };
		//	avatarContainingView.layer.shadowRadius = 1.0f;
		avatarContainingView.layer.borderColor = [UIColor whiteColor].CGColor;
		avatarContainingView.layer.borderWidth = 1.0f;
	
	}
	
	self.mainImageView.contentMode = UIViewContentModeScaleAspectFill;
	
	if (self.textEmphasisView) {
	
		self.textEmphasisView.backgroundView = [[[UIView alloc] initWithFrame:self.textEmphasisView.bounds] autorelease];
		self.textEmphasisView.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		self.textEmphasisView.font = [UIFont fontWithName:@"HelevticaNeue-Light" size:16.0];
		
		UIView *bubbleView = [[[UIView alloc] initWithFrame:self.textEmphasisView.backgroundView.bounds] autorelease];
		bubbleView.layer.contents = (id)[UIImage imageNamed:@"WASpeechBubble"].CGImage;
		bubbleView.layer.contentsCenter = (CGRect){ 80.0/128.0, 32.0/88.0, 1.0/128.0, 8.0/88.0 };
		bubbleView.frame = UIEdgeInsetsInsetRect(bubbleView.frame, (UIEdgeInsets){ -28, -32, -44, -32 });
		bubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self.textEmphasisView.backgroundView addSubview:bubbleView];
	
	}
	
	articleDescriptionLabel.font = [UIFont fontWithName:@"Georgia" size:16.0f];

}

- (void) dealloc {

	[self disassociateBindings];

	[article release];

	[contextInfoContainer release];
	[imageStackView release];
	[previewBadge release];
	[textEmphasisView release];
	[avatarView release];
	[relativeCreationDateLabel release];
	[userNameLabel release];
	[articleDescriptionLabel release];
	[contextTextView release];
	[mainImageView release];

	[super dealloc];

}




- (void) setPresentationStyle:(WAArticleViewControllerPresentationStyle)newPresentationStyle {

	if (presentationStyle == newPresentationStyle)
		return;
	
	presentationStyle = newPresentationStyle;
	
	switch (presentationStyle) {

		case WADiscreteSingleImageArticleStyle: {
			self.userNameLabel.font = [UIFont fontWithName:@"Sansus Webissimo" size:16.0f];
			//	self.articleDescriptionLabel.layer.shadowOpacity = 1;
			//	self.articleDescriptionLabel.layer.shadowOffset = (CGSize){ 0, 1 };
			break;
		}
		
		case WADiscretePlaintextArticleStyle: {
			self.userNameLabel.font = [UIFont fontWithName:@"Sansus Webissimo" size:20.0f];
			self.textEmphasisView.backgroundView = nil;
			self.textEmphasisView.backgroundColor = nil;
			break;
		}
		
		case WADiscretePreviewArticleStyle: {
			self.previewBadge.backgroundView = nil;
			self.previewBadge.titleColor = [UIColor grayColor];
			self.previewBadge.userInteractionEnabled = NO;			
			self.previewBadge.titlePlaceholder = nil;
			self.previewBadge.providerNamePlaceholder = nil;
			self.previewBadge.textPlaceholder = nil;
			break;
		}
		
		default:
			break;
		
	}


}





- (void) setArticle:(WAArticle *)newArticle {

	if (newArticle == article)
		return;
	
	[self disassociateBindings];
	
	[article release];
	article = [newArticle retain];
	
	[self associateBindings];
	
}


- (void) associateBindings {

	__block __typeof__(self) nrSelf = self;
	
	[self disassociateBindings];
	
	WAArticle *boundArticle = self.article;

	if (!boundArticle)
		return;
	
	void (^bind)(id, NSString *, id, NSString *, IRBindingsValueTransformer) = ^ (id object, NSString *objectKeyPath,  id boundObject, NSString *boundKeypath, IRBindingsValueTransformer transformerBlock) {
	
		[object irBind:objectKeyPath toObject:boundObject keyPath:boundKeypath options:[NSDictionary dictionaryWithObjectsAndKeys:
			(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
			[[transformerBlock copy] autorelease], kIRBindingsValueTransformerBlock,
		nil]];
		
	};
	
	bind(self.userNameLabel, @"text", boundArticle, @"owner.nickname", nil);
	
	bind(self.relativeCreationDateLabel, @"text", boundArticle, @"timestamp", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [[[nrSelf class] relativeDateFormatter] stringFromDate:inNewValue];
	});
	
	bind(self.articleDescriptionLabel, @"text", boundArticle, @"text", nil);
	
	bind(self.previewBadge, @"preview", boundArticle, @"previews", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return (WAPreview *)[[[inNewValue allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObjects:
			[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
		nil]] lastObject];
	});
	
	bind(self.imageStackView, @"images", boundArticle, @"representedFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? [NSArray arrayWithObject:inNewValue] : nil;
	});
	
	bind(self.mainImageView, @"image", boundArticle, @"representedFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue;
	});
	
	bind(self.mainImageView, @"backgroundColor", boundArticle, @"representedFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? [UIColor clearColor] : [UIColor colorWithWhite:0.5 alpha:1];
	});
	
	bind(self.avatarView, @"image", boundArticle, @"owner.avatar", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [inNewValue isEqual:[NSNull null]] ? nil : inNewValue;
	});
	
	bind(self.deviceDescriptionLabel, @"text", boundArticle, @"creationDeviceName", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? inNewValue : @"an unknown device";
	});
	
	bind(self.textEmphasisView, @"text", boundArticle, @"text", nil);
	
	bind(self.textEmphasisView, @"hidden", boundArticle, @"files", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [NSNumber numberWithBool:!![inNewValue count]];
	});
	
}


- (void) disassociateBindings {

	[self.userNameLabel irUnbind:@"text"];
	[self.relativeCreationDateLabel irUnbind:@"text"];
	[self.articleDescriptionLabel irUnbind:@"text"];
	[self.previewBadge irUnbind:@"preview"];
	[self.imageStackView irUnbind:@"images"];
	[self.mainImageView irUnbind:@"image"];
	[self.mainImageView irUnbind:@"backgroundColor"];
	[self.avatarView irUnbind:@"image"];
	[self.deviceDescriptionLabel irUnbind:@"text"];
	[self.textEmphasisView irUnbind:@"text"];
	[self.textEmphasisView irUnbind:@"hidden"];

}


- (void) layoutSubviews {

	[super layoutSubviews];
	
	__block __typeof__(self) nrSelf = self;

	CGPoint centerOffset = CGPointZero;

	CGRect usableRect = UIEdgeInsetsInsetRect(nrSelf.bounds, (UIEdgeInsets){ 10, 10, 32, 10 });
//	const CGFloat maximumTextWidth = MIN(CGRectGetWidth(usableRect), 480);
//	const CGFloat minimumTextWidth = MIN(maximumTextWidth, MAX(CGRectGetWidth(usableRect), 280));
	
	const CGFloat maximumTextWidth = CGRectGetWidth(usableRect);
	const CGFloat minimumTextWidth = CGRectGetWidth(usableRect);

	if (usableRect.size.width > maximumTextWidth) {
		usableRect.origin.x += roundf(0.5f * (usableRect.size.width - maximumTextWidth));
		usableRect.size.width = maximumTextWidth;
	}
	usableRect.size.width = MAX(usableRect.size.width, minimumTextWidth);
	
	CGRect textRect = usableRect;
	textRect.size.height = 1;
	textEmphasisView.frame = textRect;
	[textEmphasisView sizeToFit];
	textRect = nrSelf.textEmphasisView.frame;
	textRect.size.height = MIN(textRect.size.height, usableRect.size.height - 16 );
	textEmphasisView.frame = textRect;
	
	BOOL contextInfoAnchorsPlaintextBubble = NO;
	
	switch (presentationStyle) {
	
		case WAFullFramePlaintextArticleStyle: {
			
			centerOffset.y -= 0.5f * CGRectGetHeight(nrSelf.contextInfoContainer.frame) + 24;
			contextInfoAnchorsPlaintextBubble = NO;
			//	Fall through
			
		}
		case WAFullFrameImageStackArticleStyle:
		case WAFullFramePreviewArticleStyle: {
			
			nrSelf.previewBadge.minimumAcceptibleFullFrameAspectRatio = 0.01f;
			nrSelf.imageStackView.maxNumberOfImages = 2;
			
			break;
		
		}

		case WADiscretePlaintextArticleStyle: {
		
			nrSelf.imageStackView.maxNumberOfImages = 1;
			centerOffset.y -= 16;
		
			previewBadge.frame = UIEdgeInsetsInsetRect(self.bounds, (UIEdgeInsets){ 0, 0, 32, 0 });
			previewBadge.backgroundView = nil;
			contextInfoAnchorsPlaintextBubble = NO;
			
			break;
			
		}
		
		case WADiscreteSingleImageArticleStyle:
		case WADiscretePreviewArticleStyle: {
		
			contextInfoContainer.hidden = ![self.article.text length];
			
			[userNameLabel sizeToFit];
			[relativeCreationDateLabel sizeToFit];
			[relativeCreationDateLabel irPlaceBehindLabel:userNameLabel withEdgeInsets:(UIEdgeInsets){ 0, -8, 0, -8 }];
			[deviceDescriptionLabel sizeToFit];
			[deviceDescriptionLabel irPlaceBehindLabel:relativeCreationDateLabel withEdgeInsets:(UIEdgeInsets){ 0, -8, 0, -8 }];
			
			previewBadge.style = WAPreviewBadgeImageAndTextStyle;
			
			previewBadge.titleFont = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:22.0];
			previewBadge.titleColor = [UIColor colorWithWhite:0.25 alpha:1];
			previewBadge.providerNameFont = [UIFont systemFontOfSize:14.0];
			
			previewBadge.textFont = [UIFont fontWithName:@"Palatino-Roman" size:16.0];
			
			break;
			
		}
		
		default:
			break;
	}
	
	CGPoint center = (CGPoint){
		roundf(CGRectGetMidX(nrSelf.bounds)),
		roundf(CGRectGetMidY(nrSelf.bounds))
	};
	
	nrSelf.textEmphasisView.center = irCGPointAddPoint(center, centerOffset);
	nrSelf.textEmphasisView.frame = CGRectIntegral(nrSelf.textEmphasisView.frame);
	
	if (contextInfoAnchorsPlaintextBubble) {
		nrSelf.contextInfoContainer.frame = (CGRect){
			(CGPoint){
				CGRectGetMinX(nrSelf.textEmphasisView.frame),
				CGRectGetMaxY(nrSelf.textEmphasisView.frame) + 32
			},
			nrSelf.contextInfoContainer.frame.size
		};
	}

}




+ (IRRelativeDateFormatter *) relativeDateFormatter {

	static IRRelativeDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{

		formatter = [[IRRelativeDateFormatter alloc] init];
		formatter.approximationMaxTokenCount = 1;
			
	});

	return formatter;

}

@end
