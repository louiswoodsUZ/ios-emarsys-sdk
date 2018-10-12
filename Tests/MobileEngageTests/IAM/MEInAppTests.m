#import "Kiwi.h"
#import "MEInApp.h"
#import "MEInApp+Private.h"
#import "FakeInAppHandler.h"
#import "EMSTimestampProvider.h"
#import "FakeTimeStampProvider.h"
#import "EMSWaiter.h"

SPEC_BEGIN(MEInAppTests)
        __block MEInApp *iam;

        beforeEach(^{
            iam = [[MEInApp alloc] init];
            NSDate *renderEndTime = [NSDate dateWithTimeIntervalSince1970:103];
            EMSTimestampProvider *mockTimeStampProvider = [EMSTimestampProvider mock];
            [mockTimeStampProvider stub:@selector(provideTimestamp) andReturn:renderEndTime];
            iam.timestampProvider = mockTimeStampProvider;
        });

        describe(@"eventHandler", ^{
            it(@"should pass the eventName and payload to the given eventHandler's handleEvent:payload: method", ^{
                NSString *expectedName = @"nameOfTheEvent";
                NSDictionary <NSString *, NSObject *> *expectedPayload = @{
                    @"payloadKey1": @{
                        @"payloadKey2": @"payloadValue"
                    }
                };


                XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"expectation"];
                __block NSString *returnedEventName;
                __block NSDictionary<NSString *, NSObject *> *returnedPayload;

                FakeInAppHandler *inAppHandler = [[FakeInAppHandler alloc] initWithHandlerBlock:^(NSString *eventName, NSDictionary<NSString *, NSObject *> *payload) {
                    returnedEventName = eventName;
                    returnedPayload = payload;
                    [expectation fulfill];
                }];
                [iam setEventHandler:inAppHandler];
                NSString *message = @"<!DOCTYPE html>\n"
                                    "<html lang=\"en\">\n"
                                    "  <head>\n"
                                    "    <script>\n"
                                    "      window.onload = function() {\n"
                                    "        window.webkit.messageHandlers.triggerAppEvent.postMessage({id: '1', name: 'nameOfTheEvent', payload:{payloadKey1:{payloadKey2: 'payloadValue'}}});\n"
                                    "      };\n"
                                    "    </script>\n"
                                    "  </head>\n"
                                    "  <body style=\"background: transparent;\">\n"
                                    "  </body>\n"
                                    "</html>";
                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": @"campaignId", @"html": message}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate date]];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response] completionHandler:^{
                }];

                [XCTWaiter waitForExpectations:@[expectation] timeout:2];

                [[returnedEventName should] equal:expectedName];
                [[returnedPayload should] equal:expectedPayload];
            });

            it(@"should not try to display inapp in case if there is already one being displayed", ^{
                NSString *expectedName = @"nameOfTheEvent";
                NSDictionary <NSString *, NSObject *> *expectedPayload = @{
                    @"payloadKey1": @{
                        @"payloadKey2": @"payloadValue"
                    }
                };

                FakeInAppHandler *inAppHandler = [FakeInAppHandler mock];
                [iam setEventHandler:inAppHandler];
                NSString *message = @"<!DOCTYPE html>\n"
                                    "<html lang=\"en\">\n"
                                    "  <head>\n"
                                    "    <script>\n"
                                    "      window.onload = function() {\n"
                                    "        window.webkit.messageHandlers.triggerAppEvent.postMessage({id: '1', name: 'nameOfTheEvent', payload:{payloadKey1:{payloadKey2: 'payloadValue'}}});\n"
                                    "      };\n"
                                    "    </script>\n"
                                    "  </head>\n"
                                    "  <body style=\"background: transparent;\">\n"
                                    "  </body>\n"
                                    "</html>";
                [[inAppHandler shouldEventually] receive:@selector(handleEvent:payload:)
                                         withCountAtMost:1
                                               arguments:expectedName,
                                                         expectedPayload];

                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": @"campaignId", @"html": message}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate date]];
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
               completionHandler:^{
                   [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
                  completionHandler:^{
                      [exp fulfill];
                  }];
               }];
                [EMSWaiter waitForExpectations:@[exp] timeout:3];
            });

        });


        describe(@"showMessage", ^{
            it(@"it should set currentCampaignId", ^{
                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": @"testIdForCurrentCampaignId", @"html": @"<html></html>"}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate date]];
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
               completionHandler:^{
                   [exp fulfill];
               }];
                [EMSWaiter waitForExpectations:@[exp] timeout:30];
                [[[((id <MEIAMProtocol>) iam) currentCampaignId] should] equal:@"testIdForCurrentCampaignId"];
            });

            it(@"should call trackInAppDisplay: on inAppTracker", ^{
                id inAppTracker = [KWMock mockForProtocol:@protocol(MEInAppTrackingProtocol)];
                [[inAppTracker shouldEventuallyBeforeTimingOutAfter(30)] receive:@selector(trackInAppDisplay:)
                                                                   withArguments:@"testIdForInAppTracker"];
                iam.inAppTracker = inAppTracker;
                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": @"testIdForInAppTracker", @"html": @"<html></html>"}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate date]];
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
               completionHandler:^{
                   [exp fulfill];
               }];
                [EMSWaiter waitForExpectations:@[exp] timeout:30];
            });

            it(@"should log the rendering time", ^{
                NSString *const campaignId = @"testIdForRenderingMetric";

                NSDictionary *loadingTimeMetric = @{@"loading_time": @3000, @"id": campaignId};
                MELogRepository *mockRepository = [MELogRepository mock];
                iam.logRepository = mockRepository;
                [[mockRepository should] receive:@selector(add:) withArguments:loadingTimeMetric];

                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": campaignId, @"html": @"<html></html>"}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:100]];

                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
               completionHandler:^{
                   [exp fulfill];
               }];
                [EMSWaiter waitForExpectations:@[exp] timeout:30];
            });

            it(@"should not log the rendering time when responseModel is nil", ^{
                NSString *const campaignId = @"testIdForRenderingMetric";

                MELogRepository *mockRepository = [MELogRepository mock];
                iam.logRepository = mockRepository;
                [[mockRepository shouldNot] receive:@selector(add:)];

                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithCampaignId:campaignId
                                                                       html:@"<html></html>"]
               completionHandler:^{
                   [exp fulfill];
               }];
                [EMSWaiter waitForExpectations:@[exp]
                                       timeout:30];
            });
        });

        describe(@"MEIAMViewController", ^{
            it(@"should log the on screen time", ^{
                iam = [[MEInApp alloc] init];
                NSDate *firstTimestamp = [NSDate date];
                iam.timestampProvider = [[FakeTimeStampProvider alloc] initWithTimestamps:@[firstTimestamp, [firstTimestamp dateByAddingTimeInterval:6], [firstTimestamp dateByAddingTimeInterval:12]]];

                NSString *const campaignId = @"testIdForOnScreenMetric";

                NSDictionary *loadingTimeMetric = @{@"on_screen_time": @6000, @"id": campaignId};
                MELogRepository *mockRepository = [MELogRepository nullMock];
                iam.logRepository = mockRepository;
                [[mockRepository should] receive:@selector(add:) withArguments:loadingTimeMetric];

                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": campaignId, @"html": @"<html></html>"}}
                                                               options:0
                                                                 error:nil];
                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
                                                                                  headers:@{}
                                                                                     body:body
                                                                             requestModel:[EMSRequestModel nullMock]
                                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:100]];

                XCTestExpectation *expForRendering = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam showMessage:[[MEInAppMessage alloc] initWithResponse:response]
               completionHandler:^{
                   [expForRendering fulfill];
               }];
                [EMSWaiter waitForExpectations:@[expForRendering] timeout:30];

                XCTestExpectation *expForClosing = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [iam closeInAppMessageWithCompletionBlock:^{
                    [expForClosing fulfill];
                }];
                [EMSWaiter waitForExpectations:@[expForClosing] timeout:30];
            });
        });

        describe(@"closeInAppMessageWithCompletionBlock:", ^{

            it(@"should close the inapp message", ^{
                UIViewController *rootViewControllerMock = [UIViewController nullMock];
                [[rootViewControllerMock should] receive:@selector(dismissViewControllerAnimated:completion:)];
                KWCaptureSpy *spy = [rootViewControllerMock captureArgument:@selector(dismissViewControllerAnimated:completion:)
                                                                    atIndex:1];

                UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
                window.rootViewController = rootViewControllerMock;

                iam.iamWindow = window;

                [((id <MEIAMProtocol>) iam) closeInAppMessageWithCompletionBlock:nil];

                void (^completionBlock)(void) = spy.argument;
                completionBlock();
                [[iam.iamWindow should] beNil];
            });

        });

        describe(@"trackIAMDisplay", ^{

            xit(@"should insert inApp display event in db", ^{
//
//
//                [iam showMessage:
//               completionHandler:nil];
//
//
//                EMSConfig *config = [EMSConfig makeWithBuilder:^(EMSConfigBuilder *builder) {
//                    [builder setMobileEngageApplicationCode:@"appid"
//                                        applicationPassword:@"pw"];
//                    [builder setMerchantId:@"dummyMerchantId"];
//                    [builder setContactFieldId:@3];
//                }];
//
//                [Emarsys setupWithConfig:config];
//                FakeDbHelper *dbHelper = [FakeDbHelper new];
//                [MobileEngage setDbHelper:dbHelper];
//                MobileEngage.inApp.timestampProvider = timestampProvider;
//
//                NSString *html = @"<html><body style=\"background-color:red\"></body></html>";
//                NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"message": @{@"id": @"12345678", @"html": html}}
//                                                               options:0
//                                                                 error:nil];
//                EMSResponseModel *response = [[EMSResponseModel alloc] initWithStatusCode:200
//                                                                                  headers:@{}
//                                                                                     body:body
//                                                                             requestModel:[EMSRequestModel nullMock]
//                                                                                timestamp:[NSDate date]];
//
//
//
//
//                [[MEIAMResponseHandler new] handleResponse:response];
//
//                [dbHelper waitForInsert];
//                [[[(MEDisplayedIAM *) dbHelper.insertedModel campaignId] should] equal:@"12345678"];
            });
        });

SPEC_END