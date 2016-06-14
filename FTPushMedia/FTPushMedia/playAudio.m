//
//  playAudio.m
//  ffmpegPlayAudio
//
//  Created by infomedia  infomedia on 12-3-26.
//  Copyright (c) 2012年 infomedia. All rights reserved.
//

#import "playAudio.h"
//实际测试中发现，这个gBufferSizeBytes=0x10000;对于压缩的音频格式(mp3/aac等)没有任何问题，但是如果输入的音频文件格式是wav，会出现只播放几秒便暂停的现象；而手机又不可能去申请更大的内存去处理wav文件，不知到大家能有什么好的方法给点建议


static UInt32 gBufferSizeBytes=0x10000;//It muse be pow(2,x)
@implementation playAudio

@synthesize queue;

//回调函数(Callback)的实现
static void BufferCallback(void *inUserData,AudioQueueRef inAQ,
                           AudioQueueBufferRef buffer){
    playAudio* player=(__bridge playAudio*)inUserData;
    [player audioQueueOutputWithQueue:inAQ queueBuffer:buffer];
}


//缓存数据读取方法的实现
-(void) audioQueueOutputWithQueue:(AudioQueueRef)audioQueue queueBuffer:(AudioQueueBufferRef)audioQueueBuffer{
    OSStatus status;
    
    //读取包数据
    UInt32 numBytes;
    UInt32 numPackets=numPacketsToRead;
    status = AudioFileReadPackets(audioFile, NO, &numBytes, packetDescs, packetIndex,&numPackets, audioQueueBuffer->mAudioData);
    
    //成功读取时
    if (numPackets>0) {
        //将缓冲的容量设置为与读取的音频数据一样大小(确保内存空间)
        audioQueueBuffer->mAudioDataByteSize=numBytes;
        //完成给队列配置缓存的处理
        status = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, numPackets, packetDescs);
        //移动包的位置
        packetIndex += numPackets;
    }
}

//音频播放的初始化、实现
//在ViewController中声明一个PlayAudio对象，并用下面的方法来初始化
//self.audio=[[playAudioalloc]initWithAudio:@"/Users/xuanyuanchen/audio/daolang.mp3"];

-(id) initWithAudio:(NSString *)path{
    if (!(self=[super init])) return nil;
    UInt32 size,maxPacketSize;
    char *cookie;
    int i;
    OSStatus status;
    
    //打开音频文件
    status=AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kAudioFileReadPermission, 0, &audioFile);
    if (status != noErr) {
        //错误处理
        NSLog(@"*** Error *** PlayAudio - play:Path: could not open audio file. Path given was: %@", path);
        return nil;
    }
    
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueEnqueueBuffer(queue, buffers[i], 0, nil);
    }
    
    //取得音频数据格式
    size = sizeof(dataFormat);
    AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &size, &dataFormat);
    
    //创建播放用的音频队列
    AudioQueueNewOutput(&dataFormat, BufferCallback, (__bridge void *)(self),
                        nil, nil, 0, &queue);
    //计算单位时间包含的包数
    if (dataFormat.mBytesPerPacket==0 || dataFormat.mFramesPerPacket==0) {
        size=sizeof(maxPacketSize);
        AudioFileGetProperty(audioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
        if (maxPacketSize > gBufferSizeBytes) {
            maxPacketSize= gBufferSizeBytes;
        }
        //算出单位时间内含有的包数
        numPacketsToRead = gBufferSizeBytes/maxPacketSize;
        packetDescs=malloc(sizeof(AudioStreamPacketDescription)*numPacketsToRead);
    }else {
        numPacketsToRead= gBufferSizeBytes/dataFormat.mBytesPerPacket;
        packetDescs=nil;
    }
    
    //设置Magic Cookie，参见第二十七章的相关介绍
    AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, nil);
    if (size >0) {
        cookie=malloc(sizeof(char)*size);
        AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
        AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, cookie, size);
    }
    
    //创建并分配缓冲空间
    packetIndex=0;
    for (i=0; i<NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(queue, gBufferSizeBytes, &buffers[i]);
        //读取包数据
        if ([self readPacketsIntoBuffer:buffers[i]]==1) {
            break;
        }
    }
    
    Float32 gain=1.0;
    //设置音量
    AudioQueueSetParameter(queue, kAudioQueueParam_Volume, gain);
    //队列处理开始，此后系统开始自动调用回调(Callback)函数
    AudioQueueStart(queue, nil);
    return self;
}

-(UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)buffer {
    UInt32 numBytes,numPackets;
    
    //从文件中接受数据并保存到缓存(buffer)中
    numPackets = numPacketsToRead;
    AudioFileReadPackets(audioFile, NO, &numBytes, packetDescs, packetIndex, &numPackets, buffer->mAudioData);
    if(numPackets >0){
        buffer->mAudioDataByteSize=numBytes;
        AudioQueueEnqueueBuffer(queue, buffer, (packetDescs ? numPackets : 0), packetDescs);
        packetIndex += numPackets;
    }
    else{
        return 1;//意味着我们没有读到任何的包
    }
    return 0;//0代表正常的退出
}
@end