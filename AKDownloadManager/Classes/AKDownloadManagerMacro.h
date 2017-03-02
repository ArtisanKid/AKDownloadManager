//
//  AKDownloadManagerMacro.h
//  Pods
//
//  Created by 李翔宇 on 16/9/17.
//
//

#ifndef AKDownloadManagerMacro_h
#define AKDownloadManagerMacro_h

static BOOL AKDMLogState = YES;

#define AKDownloadManagerLogFormat(INFO, ...) [NSString stringWithFormat:(@"\n[Date:%s]\n[Time:%s]\n[File:%s]\n[Line:%d]\n[Function:%s]\n" INFO @"\n"), __DATE__, __TIME__, __FILE__, __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__]

#if DEBUG
#define AKDownloadManagerLog(INFO, ...) !AKDMLogState ? : NSLog((@"\n[Date:%s]\n[Time:%s]\n[File:%s]\n[Line:%d]\n[Function:%s]\n" INFO @"\n"), __DATE__, __TIME__, __FILE__, __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__);
#else
#define AKDownloadManagerLog(INFO, ...)
#endif

#endif /* AKDownloadManagerMacro_h */
