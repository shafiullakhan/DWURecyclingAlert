//DWURecyclingAlert.m
//Copyright (c) 2015 Di Wu
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

// Comment out if you want to disable this entire runtime hack
#define DWURecyclingAlertEnabled

// Comment out if you want to disable the millisecond counter
#define DWUMillisecondCounterEnabled

#if defined (DEBUG) && defined (DWURecyclingAlertEnabled)

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UITableViewCell.h>
#import <UIKit/UIImage.h>
#import <UIKit/UITableView.h>
#import <UIKit/UILabel.h>
#import <QuartzCore/CALayer.h>
#import <UIKit/UINibLoading.h>
#import <UIKit/UICollectionViewCell.h>
#import <UIKit/UICollectionView.h>

static const NSInteger DWU_TIME_INTERVAL_LABEL_TAG = NSIntegerMax - 123;

@interface UIView (DWURecyclingAlert)

@property (nonatomic, strong) NSNumber *dwuRecyclingCount;

@end

@implementation UIView (DWURecyclingAlert)

@dynamic dwuRecyclingCount;

- (void)setDwuRecyclingCount:(NSNumber *)number {
    objc_setAssociatedObject(self, @selector(dwuRecyclingCount), number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)dwuRecyclingCount {
    return objc_getAssociatedObject(self, @selector(dwuRecyclingCount));
}

@end

// http://www.mikeash.com/pyblog/friday-qa-2010-01-29-method-replacement-for-fun-and-profit.html
static BOOL dwu_replaceMethodWithBlock(Class c, SEL origSEL, SEL newSEL, id block) {
    if ([c instancesRespondToSelector:newSEL]) return YES; // Selector already implemented, skip silently.
    Method origMethod = class_getInstanceMethod(c, origSEL);
    IMP impl = imp_implementationWithBlock(block);
    if (!class_addMethod(c, newSEL, impl, method_getTypeEncoding(origMethod))) {
        return NO;
    }else {
        Method newMethod = class_getInstanceMethod(c, newSEL);
        if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(origMethod))) {
            class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(newMethod));
        }else {
            method_exchangeImplementations(origMethod, newMethod);
        }
    }
    return YES;
}

static void dwu_recursionHelper1(UIView *view) {
    if (view.tag == DWU_TIME_INTERVAL_LABEL_TAG) {
        return;
    }
    view.dwuRecyclingCount = @(1);
    for (UIView *subview in view.subviews) {
        dwu_recursionHelper1(subview);
    }
}

static void dwu_markAllSubviewsAsRecycled(UIView *_self) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dwu_recursionHelper1(_self);
    });
}

static void dwu_recursionHelper2(UIView *view) {
    if (view.tag == DWU_TIME_INTERVAL_LABEL_TAG) {
        return;
    }
    static NSMutableSet *cgImageRefSet;
    if (!cgImageRefSet) {
        cgImageRefSet = [NSMutableSet set];
    }
    NSNumber *recyclingCount = view.dwuRecyclingCount;
    SEL imageSelector = NSSelectorFromString(@"image");
    BOOL viewTargetFound = NO;
    BOOL imageTargetFound = NO;
    if ([view respondsToSelector:imageSelector]) {
        UIImage *image = ((UIImage * ( *)(id, SEL))objc_msgSend)(view, imageSelector);
        if (image) {
            if (![cgImageRefSet containsObject:[NSString stringWithFormat:@"%@", image.CGImage]]) {
                [cgImageRefSet addObject:[NSString stringWithFormat:@"%@", image.CGImage]];
                imageTargetFound = YES;
            }
        }
    } else if (!recyclingCount) {
        viewTargetFound = YES;
        view.dwuRecyclingCount = @(1);
    }
    
    if (viewTargetFound || imageTargetFound) {
        view.layer.borderColor = [[UIColor redColor] CGColor];
        view.layer.borderWidth = 5.0;
    } else {
        view.layer.borderColor = [[UIColor clearColor] CGColor];
        view.layer.borderWidth = 0.0;
    }
    for (UIView *subview in view.subviews) {
        dwu_recursionHelper2(subview);
    }
}

static void dwu_checkNonRecycledSubviews(UIView *_self) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dwu_recursionHelper2(_self);
    });
}

static void generateTimeLabelForUITableViewCell() {
    NSString *selStr = NSStringFromSelector(@selector(setDataSource:));
    SEL selector = NSSelectorFromString(selStr);
    SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_uitableview_%@", selStr]);
    dwu_replaceMethodWithBlock(UITableView.class, selector, newSelector, ^(__unsafe_unretained UITableViewCell *_self, __unsafe_unretained id arg) {
        NSString *cellForRowSelStr = NSStringFromSelector(@selector(tableView:cellForRowAtIndexPath:));
        SEL cellForRowSel = NSSelectorFromString(cellForRowSelStr);
        SEL newCellForRowSel = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock([arg class], cellForRowSel, newCellForRowSel, ^(__unsafe_unretained UITableView *_self, __unsafe_unretained id arg1, __unsafe_unretained id arg2) {
            NSDate *date = [NSDate date];
            id returnValue = ((id ( *)(id, SEL, id, id))objc_msgSend)(_self, newCellForRowSel, arg1, arg2);
            NSTimeInterval timeInterval = ceilf(-[date timeIntervalSinceNow] * 1000);
            NSString *timeIntervalString = [NSString stringWithFormat:@" Rendering takes %zd ms", (NSInteger)timeInterval];
            UITableViewCell *cell = (UITableViewCell *)returnValue;
            UILabel *timeIntervalLabel = (UILabel *)[cell viewWithTag:DWU_TIME_INTERVAL_LABEL_TAG];
            if (!timeIntervalLabel) {
                CGFloat labelWidth = 150.f;
                timeIntervalLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, 16)];
                timeIntervalLabel.userInteractionEnabled = NO;
                timeIntervalLabel.backgroundColor = [UIColor blackColor];
                timeIntervalLabel.textColor = [UIColor whiteColor];
                timeIntervalLabel.font = [UIFont boldSystemFontOfSize:12];
                timeIntervalLabel.textAlignment = NSTextAlignmentCenter;
                timeIntervalLabel.adjustsFontSizeToFitWidth = YES;
                timeIntervalLabel.tag = DWU_TIME_INTERVAL_LABEL_TAG;
                [cell addSubview:timeIntervalLabel];
            }
            [cell bringSubviewToFront:timeIntervalLabel];
            timeIntervalLabel.text = timeIntervalString;
            return returnValue;
        });
        ((void ( *)(id, SEL, id))objc_msgSend)(_self, newSelector, arg);
    });
}

static void generateTimeLabelForUICollectionViewCell() {
    NSString *selStr = NSStringFromSelector(@selector(setDataSource:));
    SEL selector = NSSelectorFromString(selStr);
    SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_uicollectionview_%@", selStr]);
    dwu_replaceMethodWithBlock(UICollectionView.class, selector, newSelector, ^(__unsafe_unretained UICollectionView *_self, __unsafe_unretained id arg) {
        NSString *cellForItemSelStr = NSStringFromSelector(@selector(collectionView:cellForItemAtIndexPath:));
        SEL cellForItemSel = NSSelectorFromString(cellForItemSelStr);
        SEL newCellForItemSel = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock([arg class], cellForItemSel, newCellForItemSel, ^(__unsafe_unretained UICollectionView *_self, __unsafe_unretained id arg1, __unsafe_unretained id arg2) {
            NSDate *date = [NSDate date];
            id returnValue = ((id ( *)(id, SEL, id, id))objc_msgSend)(_self, newCellForItemSel, arg1, arg2);
            NSTimeInterval timeInterval = ceilf(-[date timeIntervalSinceNow] * 1000);
            NSString *timeIntervalString = [NSString stringWithFormat:@" %zd ms", (NSInteger)timeInterval];
            UITableViewCell *cell = (UITableViewCell *)returnValue;
            UILabel *timeIntervalLabel = (UILabel *)[cell viewWithTag:DWU_TIME_INTERVAL_LABEL_TAG];
            if (!timeIntervalLabel) {
                CGFloat labelWidth = 50.f;
                timeIntervalLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, 16)];
                timeIntervalLabel.userInteractionEnabled = NO;
                timeIntervalLabel.backgroundColor = [UIColor blackColor];
                timeIntervalLabel.textColor = [UIColor whiteColor];
                timeIntervalLabel.font = [UIFont boldSystemFontOfSize:12];
                timeIntervalLabel.textAlignment = NSTextAlignmentCenter;
                timeIntervalLabel.adjustsFontSizeToFitWidth = YES;
                timeIntervalLabel.tag = DWU_TIME_INTERVAL_LABEL_TAG;
                [cell addSubview:timeIntervalLabel];
            }
            [cell bringSubviewToFront:timeIntervalLabel];
            timeIntervalLabel.text = timeIntervalString;
            return returnValue;
        });
        ((void ( *)(id, SEL, id))objc_msgSend)(_self, newSelector, arg);
    });
}

__attribute__((constructor)) static void DWURecyclingAlert(void) {
    @autoreleasepool {
        NSString *selStr = NSStringFromSelector(@selector(prepareForReuse));
        SEL selector = NSSelectorFromString(selStr);
        SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UITableViewCell.class, selector, newSelector, ^(__unsafe_unretained UITableViewCell *_self) {
            ((void ( *)(id, SEL))objc_msgSend)(_self, newSelector);
            dwu_checkNonRecycledSubviews(_self);
        });
        dwu_replaceMethodWithBlock(UICollectionViewCell.class, selector, newSelector, ^(__unsafe_unretained UICollectionViewCell *_self) {
            ((void ( *)(id, SEL))objc_msgSend)(_self, newSelector);
            dwu_checkNonRecycledSubviews(_self);
        });
        // handle "created by code" case for UITableViewCell
        selStr = NSStringFromSelector(@selector(initWithStyle:reuseIdentifier:));
        selector = NSSelectorFromString(selStr);
        newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UITableViewCell.class, selector, newSelector, (id)^(__unsafe_unretained UITableViewCell *_self, NSInteger arg1, __unsafe_unretained id arg2) {
            dwu_markAllSubviewsAsRecycled(_self);
            return ((id ( *)(id, SEL, NSInteger, id))objc_msgSend)(_self, newSelector, arg1, arg2);
        });
        // handle "created by code" case for UICollectionViewCell
        selStr = NSStringFromSelector(@selector(initWithFrame:));
        selector = NSSelectorFromString(selStr);
        newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UICollectionViewCell.class, selector, newSelector, (id)^(__unsafe_unretained UICollectionViewCell *_self, CGRect arg) {
            dwu_markAllSubviewsAsRecycled(_self);
            return ((id ( *)(id, SEL, CGRect))objc_msgSend)(_self, newSelector, arg);
        });
        // handle "created from nib" case
        selStr = NSStringFromSelector(@selector(awakeFromNib));
        selector = NSSelectorFromString(selStr);
        newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UITableViewCell.class, selector, newSelector, (id)^(__unsafe_unretained UITableViewCell *_self) {
            dwu_markAllSubviewsAsRecycled(_self);
            return ((id ( *)(id, SEL))objc_msgSend)(_self, newSelector);
        });
        dwu_replaceMethodWithBlock(UICollectionViewCell.class, selector, newSelector, (id)^(__unsafe_unretained UICollectionViewCell *_self) {
            dwu_markAllSubviewsAsRecycled(_self);
            return ((id ( *)(id, SEL))objc_msgSend)(_self, newSelector);
        });
#if defined (DEBUG) && defined (DWURecyclingAlertEnabled) && defined (DWUMillisecondCounterEnabled)
        generateTimeLabelForUITableViewCell();
        generateTimeLabelForUICollectionViewCell();
#endif
    }
}
#endif