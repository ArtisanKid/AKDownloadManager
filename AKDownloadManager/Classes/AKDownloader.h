//
//  AKDownloader.h
//  Pods
//
//  Created by 李翔宇 on 16/5/24.
//
//

#import <Foundation/Foundation.h>

@interface AKDownloader : NSObject

@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong) void(^progressBlock)(CGFloat progress);
@property (nonatomic, strong) void(^successBlock)(NSString *tmpFilePath);
@property (nonatomic, strong) void(^failureBlock)(NSError *error);
@property (nonatomic, copy) NSString *savePath;
@property (nonatomic, assign, getter=isResume) BOOL resume;

@end
