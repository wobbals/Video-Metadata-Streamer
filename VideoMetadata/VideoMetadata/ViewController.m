//
//  ViewController.m
//  VideoMetadata
//
//  Created by Charley Robinson on 6/5/14.
//
//


#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "MetadataEncoder.h"
#import "MetadataDecoder.h"
#import "TBExampleVideoRender.h"
#import "TBExampleVideoCapture.h"

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>

@end

@implementation ViewController {
    OTSession* _session;
    OTPublisherKit* _publisher;
    OTSubscriberKit* _subscriber;
    TBExampleVideoCapture* _publisherVideoCapture;
    TBExampleVideoRender* _publisherVideoRender;
    TBExampleVideoRender* _subscriberVideoRender;
    MetadataDecoder* _metadataDecoder;
    MetadataEncoder* _metadataEncoder;
}
static double widgetHeight = 240;
static double widgetWidth = 320;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"13112571";
// Replace with your generated session ID
static NSString* const kSessionId = @"1_MX4xMzExMjU3MX4xMjcuMC4wLjF-VGh1IEp1biAwNSAxMzowNjowNSBQRFQgMjAxNH4wLjQyNjQyNDU2fn4";
// Replace with your generated token
static NSString* const kToken = @"T1==cGFydG5lcl9pZD0xMzExMjU3MSZzZGtfdmVyc2lvbj10YnBocC12MC45MS4yMDExLTA3LTA1JnNpZz05ZjNlZTI0MTFkYjNiNDExMmZhZjY2MjU0MjAyYjM3OWM3ZTY4NzYxOnNlc3Npb25faWQ9MV9NWDR4TXpFeE1qVTNNWDR4TWpjdU1DNHdMakYtVkdoMUlFcDFiaUF3TlNBeE16b3dOam93TlNCUVJGUWdNakF4Tkg0d0xqUXlOalF5TkRVMmZuNCZjcmVhdGVfdGltZT0xNDAxOTk5MzI4JnJvbGU9bW9kZXJhdG9yJm5vbmNlPTE0MDE5OTkzMjguMjg4ODkwOTQ5NDM2NyZleHBpcmVfdGltZT0xNDA0NTkxMzI4";

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = YES;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Step 1: As the view comes into the foreground, initialize a new instance
    // of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (UIUserInterfaceIdiomPhone == [[UIDevice currentDevice]
                                      userInterfaceIdiom])
    {
        return NO;
    } else {
        return YES;
    }
}
#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    
    [_session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    _publisher = [[OTPublisherKit alloc] initWithDelegate:self];
    
    // inject our video capture proxy into the publisher
    _publisherVideoRender = [[TBExampleVideoRender alloc] initWithFrame:CGRectZero];
    _publisherVideoCapture = [[TBExampleVideoCapture alloc] init];
    _metadataEncoder =
    [[MetadataEncoder alloc] initWithVideoCapture:_publisherVideoCapture];
    
    [_publisher setVideoCapture:_metadataEncoder];
    [_publisher setVideoRender:_publisherVideoRender];

    [_publisher setName:[[UIDevice currentDevice] name]];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    
    [self.view addSubview:_publisherVideoRender];
    [_publisherVideoRender setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriberKit alloc] initWithStream:stream delegate:self];
    _subscriberVideoRender =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _metadataDecoder = [[MetadataDecoder alloc] initWithVideoRender:_subscriberVideoRender];
    [_subscriber setVideoRender:_metadataDecoder];
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 */
- (void)doUnsubscribe
{
    OTError *error = nil;
    [_session unsubscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    [_subscriberVideoRender removeFromSuperview];
    _subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}


- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    // Step 3a: (if NO == subscribeToSelf): Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == _subscriber && !subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self doUnsubscribe];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self doUnsubscribe];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(_subscriber == subscriber);
    [_subscriberVideoRender setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                          widgetHeight)];
    [self.view addSubview:_subscriberVideoRender];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    // Step 3b: (if YES == subscribeToSelf): Our own publisher is now visible to
    // all participants in the OpenTok session. We will attempt to subscribe to
    // our own stream. Expect to see a slight delay in the subscriber video and
    // an echo of the audio coming from the device microphone.
    if (nil == _subscriber && subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self doUnsubscribe];
    }
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
}
- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OTError"
                                                        message:string
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] ;
        [alert show];
    });
}

@end
