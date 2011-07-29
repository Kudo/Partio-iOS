//
//  WAArticleViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/28/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WAArticleViewController_iPhone.h"
#import "WADataStore.h"

#import "WAImageStackView.h"

@interface WAArticleViewController_iPhone ()

@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) WAArticle *article;

- (void) refreshView;

@end


@implementation WAArticleViewController_iPhone
@synthesize managedObjectContext, article;
@synthesize contextInfoContainer, mainContentView, avatarView, relativeCreationDateLabel, userNameLabel, articleDescriptionLabel, commentRevealButton, commentPostButton, commentCloseButton, compositionAccessoryView, compositionContentField, compositionSendButton, commentsView;

+ (WAArticleViewController_iPhone *) controllerRepresentingArticle:(NSURL *)articleObjectURL {

	WAArticleViewController_iPhone *returnedController = [[[self alloc] initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]] autorelease];
	
	returnedController.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	returnedController.article = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:articleObjectURL];
	
	return returnedController;

}

- (void) dealloc {

	[managedObjectContext release];
	[article release];
	[super dealloc];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	[self refreshView];

}

- (void) setArticle:(WAArticle *)newArticle {

	if (article == newArticle)
		return;
		
	[self willChangeValueForKey:@"article"];
	[article release];
	article = [newArticle retain];
	[self didChangeValueForKey:@"article"];
	
	if ([self isViewLoaded])
		[self refreshView];

}

- (void) refreshView {

	self.userNameLabel.text = self.article.owner.nickname;
	self.relativeCreationDateLabel.text = [self.article.timestamp description];
	self.articleDescriptionLabel.text = self.article.text;
	self.mainContentView.files = self.article.files;
	self.avatarView.image = self.article.owner.avatar;
	[self.commentsView reloadData]; // Eh?
	
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	//	Unfortunately, when using shadowPath with shouldRasterize

	for (UIView *aView in self.mainContentView.subviews) {
		CGFloat oldShadowOpacity = aView.layer.shadowOpacity;
		aView.layer.shadowOpacity = 0.0f;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * duration), dispatch_get_main_queue(), ^ {
			aView.layer.shadowOpacity = oldShadowOpacity;
		});
	}

}

@end
