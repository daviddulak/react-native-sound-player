//
//  RNSoundPlayer
//
//  Created by Johnson Su on 2018-07-10.
//

#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>
#import <React/RCTEventEmitter.h>
@import CallKit;

@interface RNSoundPlayer : RCTEventEmitter <RCTBridgeModule, AVAudioPlayerDelegate, CXCallObserverDelegate>
@property (nonatomic, strong) AVPlayer *loopingPlayer;
@property (nonatomic, strong) AVQueuePlayer *queuePlayer;
@property (nonatomic, strong) AVAudioPlayer *alertPlayer;
@property (nonatomic) int loopCount;

@property (nonatomic) float headphoneVolume;
@property (nonatomic) float speakerVolume;
@property (nonatomic) float volume;

@property (nonatomic, strong) CXCallObserver *callObserver;
@property (nonatomic) BOOL interruptedByPhoneCall;
@property (nonatomic) NSInteger phoneCallInterruptionCountdown;
@property (nonatomic) CXCall* phoneCall;

@end
