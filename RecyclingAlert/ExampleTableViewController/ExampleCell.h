//
//  ExampleCell.h
//  RecyclingAlert
//
//  Created by Di Wu on 6/7/15.
//  Copyright (c) 2015 Di Wu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ExampleCell : UITableViewCell

@end

@interface ExampleCell (LayoutSubviews)

@property (nonatomic, strong, readonly) UIImageView *recycledImageViewWithNonRecycledImage;

@property (nonatomic, strong, readonly) UIImageView *recycledImageViewWithRecycledImage;

@property (nonatomic, strong, readonly) UILabel *label0;

@property (nonatomic, strong, readonly) UILabel *label1;

@property (nonatomic, strong, readonly) UILabel *label2;

@property (nonatomic, strong, readonly) UILabel *label3;

- (void)layoutNonRecycledView: (UIView *)view;

- (void)layoutRecyledView: (UIView *)view;

- (void)layoutNonRecycledImage: (UIView *)view;

- (void)layoutRecycledImage: (UIView *)view;

@end
