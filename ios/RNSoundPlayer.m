//
//  RNSoundPlayer
//
//  Created by Johnson Su on 2018-07-10.
//

#import "RNSoundPlayer.h"

@implementation RNSoundPlayer

static NSString *const EVENT_FINISHED_LOADING = @"FinishedLoading";
static NSString *const EVENT_FINISHED_LOADING_FILE = @"FinishedLoadingFile";
static NSString *const EVENT_FINISHED_LOADING_URL = @"FinishedLoadingURL";
static NSString *const EVENT_FINISHED_PLAYING = @"FinishedPlaying";
static NSString *const EVENT_AUDIO_INTERUPTION = @"AudioInterupt";



RCT_EXPORT_METHOD(playUrl:(NSString *)url) {
    [self prepareUrl:url];
    [self.avPlayer play];
}

RCT_EXPORT_METHOD(loadUrl:(NSString *)url) {
    [self prepareUrl:url];
}

RCT_EXPORT_METHOD(playSoundFile:(NSString *)name ofType:(NSString *)type) {
    [self mountSoundFile:name ofType:type];
    [self.player play];
}

RCT_EXPORT_METHOD(playSoundFileWithDelay:(NSString *)name ofType:(NSString *)type delay:(double)delay) {
    [self mountSoundFile:name ofType:type];
    [self.player playAtTime:(self.player.deviceCurrentTime + delay)];
}

RCT_EXPORT_METHOD(loadSoundFile:(NSString *)name ofType:(NSString *)type) {
    [self mountSoundFile:name ofType:type];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[EVENT_FINISHED_PLAYING, EVENT_FINISHED_LOADING, EVENT_FINISHED_LOADING_URL, EVENT_FINISHED_LOADING_FILE, EVENT_AUDIO_INTERUPTION];
}

RCT_EXPORT_METHOD(pause) {
    if (self.player != nil) {
        [self.player pause];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer pause];
    }
}

RCT_EXPORT_METHOD(resume) {
    if (self.player != nil) {
        [self.player play];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer play];
    }
}

RCT_EXPORT_METHOD(stop) {
    if (self.player != nil) {
        [self.player stop];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer pause];
    }
}

RCT_EXPORT_METHOD(seek:(float)seconds) {
    if (self.player != nil) {
        self.player.currentTime = seconds;
    }
    if (self.avPlayer != nil) {
        [self.avPlayer seekToTime: CMTimeMakeWithSeconds(seconds, 1.0)];
    }
}

#if !TARGET_OS_TV
RCT_EXPORT_METHOD(setSpeaker:(BOOL) on) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if (on) {
        [session setCategory: AVAudioSessionCategoryPlayAndRecord error: nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    } else {
        [session setCategory: AVAudioSessionCategoryPlayback error: nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }
    [session setActive:true error:nil];
}
#endif

RCT_EXPORT_METHOD(setMixAudio:(BOOL) on) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    if (on) {
        [session setCategory: AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    } else {
        [session setCategory: AVAudioSessionCategoryPlayback withOptions:0 error:nil];
    }
    [session setActive:true error:nil];
}

RCT_EXPORT_METHOD(setVolume:(float) volume) {
    if (self.player != nil) {
        [self.player setVolume: volume];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer setVolume: volume];
    }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(NSInteger) loopCount) {
    self.loopCount = loopCount;
    if (self.player != nil) {
        [self.player setNumberOfLoops:loopCount];
    }
}

RCT_REMAP_METHOD(getInfo,
                 getInfoWithResolver:(RCTPromiseResolveBlock) resolve
                 rejecter:(RCTPromiseRejectBlock) reject) {
    if (self.player != nil) {
        NSDictionary *data = @{
            @"currentTime": [NSNumber numberWithDouble:[self.player currentTime]],
            @"duration": [NSNumber numberWithDouble:[self.player duration]]
        };
        resolve(data);
        return;
    }
    if (self.avPlayer != nil) {
        CMTime currentTime = [[self.avPlayer currentItem] currentTime];
        CMTime duration = [[[self.avPlayer currentItem] asset] duration];
        NSDictionary *data = @{
            @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(currentTime)],
            @"duration": [NSNumber numberWithFloat:CMTimeGetSeconds(duration)]
        };
        resolve(data);
        return;
    }
    resolve(nil);
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:flag]}];
}

- (void) itemDidFinishPlaying:(NSNotification *) notification {
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:TRUE]}];
}

- (void) mountSoundFile:(NSString *)name ofType:(NSString *)type {
    if (self.avPlayer) {
        self.avPlayer = nil;
    }
    
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:name ofType:type];
    
    if (soundFilePath == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        soundFilePath = [NSString stringWithFormat:@"%@.%@", [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",name]], type];
    }
    
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    [self.player setDelegate:self];
    [self.player setNumberOfLoops:self.loopCount];
    [self.player prepareToPlay];
    [[AVAudioSession sharedInstance]
            setCategory: AVAudioSessionCategoryPlayAndRecord
            error: nil];
    
    //detect the headphone pull
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVAudioSessionRouteChangeNotification:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];

    //handle interruptions like phone calls and siri
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVAudioSessionInterruptionNotification:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];

    //supposedly Mediaserverd resets are rare, but have been seen during development...
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionMediaServicesWereLostNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVAudioSessionMediaServicesWereLostNotification:)
                                                 name:AVAudioSessionMediaServicesWereLostNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVAudioSessionMediaServicesWereResetNotification:)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:nil];

    [[MPMusicPlayerController systemMusicPlayer] beginGeneratingPlaybackNotifications];
    
    // Listen for volume changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMusicPlayerControllerVolumeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVolumeChangeNotification:)
                                                 name:MPMusicPlayerControllerVolumeDidChangeNotification
                                               object:[MPMusicPlayerController systemMusicPlayer]];
    
    [self sendEventWithName:EVENT_FINISHED_LOADING body:@{@"success": [NSNumber numberWithBool:true]}];
    [self sendEventWithName:EVENT_FINISHED_LOADING_FILE body:@{@"success": [NSNumber numberWithBool:true], @"name": name, @"type": type}];
}

- (void) prepareUrl:(NSString *)url {
    if (self.player) {
        self.player = nil;
    }
    NSURL *soundURL = [NSURL URLWithString:url];
    
    if (!self.avPlayer) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    
    self.avPlayer = [[AVPlayer alloc] initWithURL:soundURL];
    [self.player prepareToPlay];
    [self sendEventWithName:EVENT_FINISHED_LOADING body:@{@"success": [NSNumber numberWithBool:true]}];
    [self sendEventWithName:EVENT_FINISHED_LOADING_URL body: @{@"success": [NSNumber numberWithBool:true], @"url": url}];
}

- (void)handleAVAudioSessionRouteChangeNotification:(NSNotification *)notification {
    //we do not want to mess around with volume during Timer sessions
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    NSInteger routeChangeReason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
    //this will force the new output route volume to be whatever they set the old route volume to be
    //useful if they think they are changing volume with tether plugged in (headphone)
    //so when tether pulled (speaker) its the same as what they set
    NSLog(@"--> Media System:%f    Speaker:%f   Headphones:%f",self.volume, self.speakerVolume, self.headphoneVolume);
    float volume = self.volume;
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            //changed from speaker to headphones
            NSLog(@"--> Media Applying Speaker Volume to Headphones");
            if (volume != self.speakerVolume) {
                self.volume = self.speakerVolume;
            }
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            //changed from headphone to speaker
            NSLog(@"--> Media Applying Headphone Volume to Speaker");
            if (volume != self.headphoneVolume) {
                self.volume = self.headphoneVolume;
            }
            break;
        default:
            break;
    }
}

- (void)handleAVAudioSessionMediaServicesWereLostNotification:(NSNotification *)notification {
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    CLS_LOG(@"--> Media Services Lost!");
    // @ [_alarmManager sendSessionPause];
}

- (void)handleAVAudioSessionMediaServicesWereResetNotification:(NSNotification *)notification {
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    CLS_LOG(@"--> Media Services Reset!");
    // @ [_alarmManager sendSessionResume];
}

- (void)handleAVAudioSessionInterruptionNotification:(NSNotification *)notification {
    //session was interrupted by external app or process
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    NSInteger interruptReason = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    if (interruptReason == AVAudioSessionInterruptionTypeBegan) {
        CLS_LOG(@"--> Media Audio Session Interrupted!  Pausing");
        [self sendEventWithName:EVENT_AUDIO_INTERUPTION body:@{@"success": [NSNumber numberWithBool:true]}];
        // @ [_alarmManager sendSessionPause];
    } else {
        //when resuming Audio, determine if we were on a Phone Call and handle that differently
        CLS_LOG(@"--> Media Audio Session Interrupted!  Resume");
        [self sendEventWithName:EVENT_AUDIO_INTERUPTION body:@{@"success": [NSNumber numberWithBool:true]}];
        // @ [self handleAudioSessionResume];
    }
}

RCT_EXPORT_MODULE();

@end
