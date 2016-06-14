//
//  Video.m
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
//  Copyright 2010 www.codza.com. All rights reserved.
//

#import "VideoFrameExtractor.h"
#import "Utilities.h"
#include "libavformat/avformat.h"
#include "libavutil/mathematics.h"
#include "libavutil/time.h"

SwrContext* setupResampler2(AVCodecContext* pCodecCtx);
void dellocSwrContext(SwrContext* swrCtx);
@interface VideoFrameExtractor (private)
-(void)convertFrameToRGB;
-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;
-(void)savePicture:(AVPicture)pFrame width:(int)width height:(int)height index:(int)iFrame;
-(void)setupScaler;
@end

@implementation VideoFrameExtractor

@synthesize outputWidth, outputHeight;

-(void)setOutputWidth:(int)newValue {
    if (outputWidth == newValue) return;
    outputWidth = newValue;
    [self setupScaler];
}

-(void)setOutputHeight:(int)newValue {
    if (outputHeight == newValue) return;
    outputHeight = newValue;
    [self setupScaler];
}

-(UIImage *)currentImage {
    //    return self.image;
    if (!pFrame->data[0]) return nil;
    [self convertFrameToRGB];
    return [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
}


- (NSInteger)getAudioBuffer:(AVPacket *)packetT{
    if (packetT->stream_index != videoStream) {
        int got_frame_ptr = 0;
        AVFrame *frame = av_frame_alloc();
//        do{
        avcodec_decode_audio4(aCodecCtx, frame, &got_frame_ptr, packetT);
//        }while (!got_frame_ptr);
        
        if (got_frame_ptr <= 0) {
            fprintf(stderr, "Error while decoding\n");
//            av_frame_free(&(frame));
            return got_frame_ptr;
        }
        int ret = swr_convert(swrCtx, &_frame_buf, frame->nb_samples * 2, (const uint8_t**)frame->extended_data, frame->nb_samples * 2);
        av_frame_free(&(frame));
        if (ret < 0)
            return -1;
        return ret;
    }
    return -1;
}


-(double)duration {
    return (double)pFormatCtx->duration / AV_TIME_BASE;
}

-(double)currentTime {
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}

-(int)sourceWidth {
    return pCodecCtx->width;
}

-(int)sourceHeight {
    return pCodecCtx->height;
}

-(id)initWithVideo:(NSString *)moviePath {
    if (!(self=[super init])) return nil;
    
    AVCodec         *pCodec;
    AVCodec         *aCodec;
    
    // Register all formats and codecs
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    // Open video file
    if(avformat_open_input(&pFormatCtx, [moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
    
    // Retrieve stream information
    if(avformat_find_stream_info(pFormatCtx,NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    
    int size = 1024;// av_samples_get_buffer_size(NULL, context->channels,context->frame_size,context->sample_fmt, 1);
    //
    _frame_buf = av_mallocz(size * 2);
    
    // Find the first video stream
    if ((videoStream =  av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &aCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        goto initError;
    }
    // Find the first video stream
    if ((audioStream =  av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        goto initError;
    }
    
    // Get a pointer to the codec context for the video stream
//    pCodecCtx = pFormatCtx->streams[videoStream]->codec;
    
    
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(pFormatCtx->streams[videoStream]->codec->codec_id);
    if(pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        goto initError;
    }
    
    pCodecCtx = avcodec_alloc_context3(pCodec);
    
    avcodec_copy_context(pCodecCtx, pFormatCtx->streams[videoStream]->codec);
    // Open codec
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
    }
    
//    aCodecCtx = pFormatCtx->streams[audioStream]->codec;
    aCodec =avcodec_find_decoder(pFormatCtx->streams[audioStream]->codec->codec_id);//
    if (!aCodec) {
        fprintf(stderr, "codec not found\n");
        goto initError;
    }
    
    aCodecCtx = avcodec_alloc_context3(aCodec);
    
    avcodec_copy_context(aCodecCtx, pFormatCtx->streams[audioStream]->codec);
    
    aCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    /* open it */
    if (avcodec_open2(aCodecCtx, aCodec,0) < 0) {
        fprintf(stderr, "could not open codec\n");
        goto initError;
    }
    
    
    if (!(swrCtx = setupResampler2(aCodecCtx))) {
        fprintf(stderr, "could not swr_alloc_set_opts\n");
        goto initError;
    }
    
    //    if (!aCodecCtx) {
    //        AVCodecContext *deContext = pFormatCtx->streams[audioStream]->codec;
    //        {
    //            aCodec =avcodec_find_decoder(AV_CODEC_ID_AAC);//
    //            if (!aCodec) {
    //                fprintf(stderr, "codec not found\n");
    //                exit(1);
    //            }
    //            aCodecCtx = avcodec_alloc_context3(aCodec);
    //
    //            avcodec_copy_context(aCodecCtx, deContext);
    //            aCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    //            /* open it */
    //            if (avcodec_open2(aCodecCtx, aCodec,0) < 0) {
    //                fprintf(stderr, "could not open codec\n");
    //                goto initError;
    //            }
    //        }
    //    }
    
    
    // Allocate video frame
    pFrame = av_frame_alloc();
    
    outputWidth = pCodecCtx->width;
    self.outputHeight = pCodecCtx->height;
    
    return self;
    
initError:
    [self release];
    return nil;
}


SwrContext* setupResampler2(AVCodecContext* pCodecCtx)
{
    struct SwrContext* swrCtx = swr_alloc_set_opts(nil,
                                                   pCodecCtx->channel_layout,
                                                   AV_SAMPLE_FMT_S16,
                                                   pCodecCtx->sample_rate,
                                                   pCodecCtx->channel_layout,
                                                   pCodecCtx->sample_fmt,
                                                   pCodecCtx->sample_rate,
                                                   0,
                                                   nil);
    //    swrCtx = swr_alloc_set_opts(nil,
    //                                pCodecCtx->channel_layout,
    //                                pCodecCtx->sample_fmt,
    //                                pCodecCtx->sample_rate,
    //                                pCodecCtx->channel_layout,
    //                                AV_SAMPLE_FMT_S16,
    //                                pCodecCtx->sample_rate,
    //                                0,
    //                                nil);
    
    if (!swrCtx || swr_init(swrCtx) < 0) {
        return NULL;
    }
    return swrCtx;
}


void dellocSwrContext(SwrContext* swrCtx)
{
    swr_free(&swrCtx);
}


-(void)setupScaler {
    
    // Release old picture and scaler
    avpicture_free(&picture);
    sws_freeContext(img_convert_ctx);
    
    // Allocate RGB picture
    avpicture_alloc(&picture, PIX_FMT_RGB24, outputWidth, outputHeight);
    
    // Setup scaler
    static int sws_flags =  SWS_FAST_BILINEAR;
    img_convert_ctx = sws_getContext(pCodecCtx->width,
                                     pCodecCtx->height,
                                     pCodecCtx->pix_fmt,
                                     outputWidth,
                                     outputHeight,
                                     PIX_FMT_RGB24,
                                     sws_flags, NULL, NULL, NULL);
    //
    //
    //    struct SwsContext* cc = sws_getContext(192, 144,
    //                                           PIX_FMT_YUV420P,//PIX_FMT_RGB24 PIX_FMT_RGB32 PIX_FMT_YUV420P
    //                                           192, 144,
    //                                           PIX_FMT_RGB32,
    //                                           SWS_FAST_BILINEAR, NULL, NULL, NULL);//
    //    NSLog(@"sdf");
    
}

-(void)seekTime:(double)seconds {
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(pCodecCtx);
}

-(void)dealloc {
    // Free scaler
    sws_freeContext(img_convert_ctx);
    
    // Free RGB picture
    avpicture_free(&picture);
    
    // Free the packet that was allocated by av_read_frame
    av_free_packet(&packet);
    
    // Free the YUV frame
    av_frame_free(&(pFrame));
    
    // Close video the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
    
    // Close audio the codec
    if (aCodecCtx) avcodec_close(aCodecCtx);
    
    dellocSwrContext(swrCtx);
    
    // Close the video file
    if (pFormatCtx) avformat_close_input(&pFormatCtx);
    
    [super dealloc];
}

-(BOOL)stepFrame {
    // AVPacket packet;
    int frameFinished=0;
    
    AVPacket packetTemp;
    av_init_packet(&packetTemp);
    while(!frameFinished && av_read_frame(pFormatCtx, &packetTemp)>=0) {
        // Is this a packet from the video stream?
        if(packetTemp.stream_index==videoStream)
        {
            //            if(packet.stream_index==videoStream) {
            // Decode video frame
            //            avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
            NSLog(@"videoStream size : pts %lld, dts %lld duration %d", packetTemp.pts, packetTemp.dts, packetTemp.duration);
        }else{
            NSLog(@"audioStream size : pts %lld, dts %lld duration %d", packetTemp.pts, packetTemp.dts, packetTemp.duration);
        }
        
        av_free_packet(&packetTemp);
        return YES;
        
    }
    return frameFinished!=0;
}

-(BOOL)getPacket{
    
    AVPacket packetTemp;
    av_init_packet(&packetTemp);
    while(av_read_frame(pFormatCtx, &packetTemp)>=0) {
        // Is this a packet from the video stream?
        if(packetTemp.stream_index==videoStream){
            // Decode video frame
            // AVPacket packet;
            int frameFinished=0;
//            do{
            avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packetTemp);
//            }while (!frameFinished);
            
            NSLog(@"videoStream size : pts %lld, dts %lld duration %d", packetTemp.pts, packetTemp.dts, packetTemp.duration);
            if (frameFinished != 0) {
                av_free_packet(&packetTemp);
            } else {
                NSLog(@"video token");
//                continue;
            }
            return YES;
        }else{
            self.count = [self getAudioBuffer:&packetTemp];
            NSLog(@"audioStream size : pts %lld, dts %lld duration %d", packetTemp.pts, packetTemp.dts, packetTemp.duration);
            if (self.count != 0) {
                av_free_packet(&packetTemp);
            }else{
                NSLog(@"audio token");
                continue;
            }
            return NO;
        }
        
    }
    return NO;
}

-(void)convertFrameToRGB {
    sws_scale (img_convert_ctx, (const uint8_t**)(pFrame->data), pFrame->linesize,
               0, pCodecCtx->height,
               picture.data, picture.linesize);
}

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    //    self.image = image;
    return image;
}

-(void)savePPMPicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame {
    FILE *pFile;
    NSString *fileName;
    int  y;
    
    fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if(pFile==NULL)
        return;
    
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
    
    // Write pixel data
    for(y=0; y<height; y++)
        fwrite(pict.data[0]+y*pict.linesize[0], 1, width*3, pFile);
    
    // Close file
    fclose(pFile);
}

@end
