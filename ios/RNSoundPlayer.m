//
//  RNSoundPlayer
//
//  Created by Johnson Su on 2018-07-10.
//

#import "RNSoundPlayer.h"

@interface RNSoundPlayer ()
@property (nonatomic) BOOL activatingAudioSession;
@end

@implementation RNSoundPlayer

static NSString *const EVENT_FINISHED_LOADING = @"FinishedLoading";
static NSString *const EVENT_FINISHED_LOADING_FILE = @"FinishedLoadingFile";
static NSString *const EVENT_FINISHED_LOADING_URL = @"FinishedLoadingURL";
static NSString *const EVENT_FINISHED_PLAYING = @"FinishedPlaying";
static NSString *const EVENT_AUDIO_INTERUPTION = @"AudioInterupt";


RCT_EXPORT_METHOD(startSession) {
    [self startAudioSession];
}

RCT_EXPORT_METHOD(playUrl:(NSString *)url) {
    [self prepareUrl:url];
    [self.loopingPlayer play];
}

RCT_EXPORT_METHOD(loadUrl:(NSString *)url) {
    [self prepareUrl:url];
}

RCT_EXPORT_METHOD(playSoundFile:(NSString *)name ofType:(NSString *)type) {
    [self mountSoundFile:name ofType:type];
    [self.alertPlayer play];
}

RCT_EXPORT_METHOD(playSoundFileWithDelay:(NSString *)name ofType:(NSString *)type delay:(double)delay) {
    [self mountSoundFile:name ofType:type];
    [self.alertPlayer playAtTime:(self.alertPlayer.deviceCurrentTime + delay)];
}

RCT_EXPORT_METHOD(loadSoundFile:(NSString *)name ofType:(NSString *)type) {
    [self mountSoundFile:name ofType:type];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[EVENT_FINISHED_PLAYING, EVENT_FINISHED_LOADING, EVENT_FINISHED_LOADING_URL, EVENT_FINISHED_LOADING_FILE, EVENT_AUDIO_INTERUPTION];
}

RCT_EXPORT_METHOD(pause) {
    if (self.alertPlayer != nil) {
        [self.alertPlayer pause];
    }
    if (self.loopingPlayer != nil) {
        [self.loopingPlayer pause];
    }
}

RCT_EXPORT_METHOD(resume) {
    if (self.alertPlayer != nil) {
        [self.alertPlayer play];
    }
    if (self.loopingPlayer != nil) {
        [self.loopingPlayer play];
    }
}

RCT_EXPORT_METHOD(stop) {
    if (self.alertPlayer != nil) {
        [self.alertPlayer stop];
    }
    if (self.loopingPlayer != nil) {
        [self.loopingPlayer pause];
    }
}

RCT_EXPORT_METHOD(seek:(float)seconds) {
    if (self.alertPlayer != nil) {
        self.alertPlayer.currentTime = seconds;
    }
    if (self.loopingPlayer != nil) {
        [self.loopingPlayer seekToTime: CMTimeMakeWithSeconds(seconds, 1.0)];
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
    if (self.alertPlayer != nil) {
        [self.alertPlayer setVolume: volume];
    }
    if (self.loopingPlayer != nil) {
        [self.loopingPlayer setVolume: volume];
    }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(NSInteger) loopCount) {
    self.loopCount = loopCount;
    if (self.alertPlayer != nil) {
        [self.alertPlayer setNumberOfLoops:loopCount];
    }
}

RCT_REMAP_METHOD(getInfo,
                 getInfoWithResolver:(RCTPromiseResolveBlock) resolve
                 rejecter:(RCTPromiseRejectBlock) reject) {
    if (self.alertPlayer != nil) {
        NSDictionary *data = @{
            @"currentTime": [NSNumber numberWithDouble:[self.alertPlayer currentTime]],
            @"duration": [NSNumber numberWithDouble:[self.alertPlayer duration]]
        };
        resolve(data);
        return;
    }
    if (self.loopingPlayer != nil) {
        CMTime currentTime = [[self.loopingPlayer currentItem] currentTime];
        CMTime duration = [[[self.loopingPlayer currentItem] asset] duration];
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
    NSLog(@"--> audioPlayerDidFinishPlaying");
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:flag]}];
}

- (void) itemDidFinishPlaying:(NSNotification *) notification {
    NSLog(@"--> itemDidFinishPlaying");
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:TRUE]}];
}

- (void) mountSoundFile:(NSString *)name ofType:(NSString *)type {
    if (self.loopingPlayer) {
        self.loopingPlayer = nil;
    }
    
    NSLog(@"--> mountSoundFile");
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:name ofType:type];
    
    //ensure we don't change the volume when we change the category type
    float currentVolume = self.volume;
    
    if (soundFilePath == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        soundFilePath = [NSString stringWithFormat:@"%@.%@", [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",name]], type];
    }
    
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    self.alertPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    [self.alertPlayer setDelegate:self];
    [self.alertPlayer setNumberOfLoops:self.loopCount];
    [self.alertPlayer prepareToPlay];
    [[AVAudioSession sharedInstance]
            setCategory: AVAudioSessionCategoryPlayAndRecord
     error: nil];
    
    [self sendEventWithName:EVENT_FINISHED_LOADING body:@{@"success": [NSNumber numberWithBool:true]}];
    [self sendEventWithName:EVENT_FINISHED_LOADING_FILE body:@{@"success": [NSNumber numberWithBool:true], @"name": name, @"type": type}];
}

- (void) prepareUrl:(NSString *)url {
    if (self.alertPlayer) {
        self.alertPlayer = nil;
    }
    NSURL *soundURL = [NSURL URLWithString:url];
    
    NSLog(@"--> prepareUrl");
    
    if (!self.loopingPlayer) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    
    self.loopingPlayer = [[AVPlayer alloc] initWithURL:soundURL];
    [self.alertPlayer prepareToPlay];
    [self sendEventWithName:EVENT_FINISHED_LOADING body:@{@"success": [NSNumber numberWithBool:true]}];
    [self sendEventWithName:EVENT_FINISHED_LOADING_URL body: @{@"success": [NSNumber numberWithBool:true], @"url": url}];
}









// handle session


- (void)activateAudioSessionWithCategory:(NSString*)theCategory {
    
    //this is called from pollTether, so prevents overlap if it takes longer than 1s
    if (_activatingAudioSession) {
        NSLog(@"--> Already trying to activate the audio session, skip this time");
        return;
    }
    _activatingAudioSession = YES;
    
    //ensure we don't change the volume when we change the category type
    float currentVolume = self.volume;
    
    NSLog(@"--> Activating Audio Session and setting Category to %@", theCategory);
    //Playback removes ability to detect headphones while connected to bluetooth
    if (theCategory == nil) {
        theCategory = [AVAudioSession sharedInstance].category;
        NSLog(@"--> Using current category of %@",theCategory);
    }
    NSError *theError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:theCategory withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&theError];
    if (!success) {
        NSLog(@"--> Error setting category! %@", theError);
    }
    
    success = [[AVAudioSession sharedInstance] setActive:YES error:&theError];
    if (!success) {
        NSLog(@"--> Error activating! %@", theError);
//        _alarmManager.isAudioSessionInterrupted = YES;
    } else {
        self.volume = currentVolume;
        NSLog(@"--> Activation Success!");
        //we have control again, reset flag
//        if (_alarmManager.isAudioSessionInterrupted) {
//            //currently interrupted, but changing to NOT interrupted, so send Resume
//            [self handleAudioSessionResume];
//        }
//        _alarmManager.isAudioSessionInterrupted = NO;
    }
    _activatingAudioSession = NO;
}


- (void)startAudioSession {
    NSLog(@"--> Starting Audio Session");

    //activate the session first.  PlayAndRecord avoids bluetooth issues with tether detectionr
    [self activateAudioSessionWithCategory:AVAudioSessionCategoryPlayAndRecord];

    //setup lock screen to show the "song" info
//    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
//
//    commandCenter.previousTrackCommand.enabled = NO;
//    commandCenter.skipBackwardCommand.enabled = NO;
//    commandCenter.seekBackwardCommand.enabled = NO;
//    commandCenter.pauseCommand.enabled = NO;
//    commandCenter.playCommand.enabled = NO;
//    // Per stackoverflow, You must also register for any other command in order to take control
//    // of the command center, or else disabling other commands does not work.
//    // For example:
//    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];

    /*** Manage the tetherTimer outside of this
    //tether timer owned and controlled by SSAlarmManager
    if (_alarmManager.tetherTimer != nil) {
        [_alarmManager.tetherTimer invalidate];
        _alarmManager.tetherTimer = nil;
    }
    CLS_LOG(@"Starting Tether Timer");
    _alarmManager.tetherTimer = [NSTimer scheduledTimerWithTimeInterval:TETHER_TIMER_INTERVAL target:_alarmManager selector:@selector(pollTether:) userInfo:nil repeats:YES];
     */
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

//    [[MPMusicPlayerController systemMusicPlayer] beginGeneratingPlaybackNotifications];
//
//    // Listen for volume changes
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMusicPlayerControllerVolumeDidChangeNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(handleVolumeChangeNotification:)
//                                                 name:MPMusicPlayerControllerVolumeDidChangeNotification
//                                               object:[MPMusicPlayerController systemMusicPlayer]];
}






// event handlers

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
    
    NSLog(@"--> Media Services Lost!");
    // @ [_alarmManager sendSessionPause];
}

- (void)handleAVAudioSessionMediaServicesWereResetNotification:(NSNotification *)notification {
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    NSLog(@"--> Media Services Reset!");
    // @ [_alarmManager sendSessionResume];
}

- (void)handleAVAudioSessionInterruptionNotification:(NSNotification *)notification {
    //session was interrupted by external app or process
    // @ if (![SSAlarmManager sharedInstance].isTetherSession) return;
    
    NSInteger interruptReason = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    if (interruptReason == AVAudioSessionInterruptionTypeBegan) {
        NSLog(@"--> Media Audio Session Interrupted!  Pausing");
        [self sendEventWithName:EVENT_AUDIO_INTERUPTION body:@{@"success": [NSNumber numberWithBool:true]}];
        // @ [_alarmManager sendSessionPause];
    } else {
        //when resuming Audio, determine if we were on a Phone Call and handle that differently
        NSLog(@"--> Media Audio Session Interrupted!  Resume");
        [self sendEventWithName:EVENT_AUDIO_INTERUPTION body:@{@"success": [NSNumber numberWithBool:true]}];
        // @ [self handleAudioSessionResume];
    }
}

RCT_EXPORT_MODULE();

@end
