//
//  FFInputFile.m
//  LiveStreamer
//
//  Created by Christopher Ballinger on 10/1/13.
//  Copyright (c) 2013 OpenWatch, Inc. All rights reserved.
//

#import "FFInputFile.h"
#import "FFInputStream.h"
#import "FFUtilities.h"

NSString const *kFFmpegInputFormatKey = @"kFFmpegInputFormatKey";

@implementation FFInputFile
@synthesize endOfFileReached, timestampOffset, lastTimestamp, formatContext;

- (void) dealloc {
    avformat_close_input(&formatContext);
}

- (AVFormatContext*) formatContextForInputPath:(NSString*)inputPath options:(NSDictionary*)options {
    // You can override the detected input format
    AVFormatContext *inputFormatContext = NULL;
    AVInputFormat *inputFormat = NULL;
    AVDictionary *inputOptions = NULL;
    
    NSString *inputFormatString = [options objectForKey:kFFmpegInputFormatKey];
    if (inputFormatString) {
        inputFormat = av_find_input_format([inputFormatString UTF8String]);
    }
    // bool b=
    [[NSFileManager defaultManager] fileExistsAtPath:inputPath]; // edited May 2018
    
    NSError *attributesError = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:inputPath error:&attributesError];
    
    
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    // long long fileSize =
    [fileSizeNumber longLongValue]; // edited May 2018
    if (fileSizeNumber.longValue == 0) {
        printf("ERROR: File size is 0");
        return nil;
    }
    
    //printf("FFINPUTFILE start \n");
    // It's possible to send more options to the parser
    // https://stackoverflow.com/questions/38255749/c-h264-ffmpeg-libav-encode-decodelossless-issues#38283546
    av_dict_set(&inputOptions, "crf", "0", 0); // removes compression // TODO maybe shouldnt be hard coded here
    // av_dict_set(&inputOptions, "pixel_format", "rgb24", 0);
    //printf("\n FFINPUTFILE end \n");
    
    int openInputValue = avformat_open_input(&inputFormatContext, [inputPath UTF8String], inputFormat, &inputOptions);
    if (openInputValue != 0) {
        avformat_close_input(&inputFormatContext);
        return nil;
    }
    
    int streamInfoValue = avformat_find_stream_info(inputFormatContext, NULL);
    if (streamInfoValue < 0) {
        avformat_close_input(&inputFormatContext);
        return nil;
    }
    
    av_dict_free(&inputOptions); // Don't forget to free // added may 2018
    
    return inputFormatContext;
}

- (void) populateStreams {
    // TODO sometimes throws error here: Thread 8: EXC_BAD_ACCESS (code=1, address=0x2c)
    if (formatContext == NULL) {
        printf("WHY IS THIS FUCKIN NULL");
    }
    NSUInteger inputStreamCount = formatContext->nb_streams; // FormatContext == NULL
    NSMutableArray *inputStreams = [NSMutableArray arrayWithCapacity:inputStreamCount];
    for (int i = 0; i < inputStreamCount; i++) {
        AVStream *inputStream = formatContext->streams[i];
        FFInputStream *ffInputStream = [[FFInputStream alloc] initWithInputFile:self stream:inputStream];
        [inputStreams addObject:ffInputStream];
    }
    self.streams = inputStreams;
}

- (id) initWithPath:(NSString *)path options:(NSDictionary *)options {
    if (self = [super initWithPath:path options:options]) {
        self.formatContext = [self formatContextForInputPath:path options:options];
        if (formatContext == NULL) {
            // FIRST HERE
            printf("WHY IS formatContext FUCKIN NULL?");
        }
        [self populateStreams];
    }
    return self;
}

- (BOOL) readFrameIntoPacket:(AVPacket*)packet error:(NSError *__autoreleasing *)error {
    BOOL continueReading = YES;
    int frameReadValue = av_read_frame(self.formatContext, packet);
    if (frameReadValue != 0) {
        continueReading = NO;
        if (frameReadValue != AVERROR_EOF) {
            if (error != NULL) {
                *error = [FFUtilities errorForAVError:frameReadValue];
            }
        }
        av_free_packet(packet);
    }
    return continueReading;
}

@end
