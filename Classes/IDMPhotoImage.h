//
//  IDMPhotoImage.h
//  PhotoBrowserDemo
//
//  Created by shifted on 2017. 7. 7..
//
//

#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImage.h>

@interface IDMPhotoImage : NSObject

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) SDAnimatedImage *animatedImage;

@end
