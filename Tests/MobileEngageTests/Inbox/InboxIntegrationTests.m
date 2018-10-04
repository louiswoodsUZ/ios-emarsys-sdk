#import "Kiwi.h"
#import "EMSConfigBuilder.h"
#import "EMSConfig.h"
#import "EMSNotificationInboxStatus.h"
#import "EMSWaiter.h"
#import "Emarsys.h"

#define DB_PATH [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"EMSSQLiteQueueDB.db"]

SPEC_BEGIN(InboxIntegrationTests)

        beforeEach(^{
            [[NSFileManager defaultManager] removeItemAtPath:DB_PATH
                                                       error:nil];

            EMSConfig *config = [EMSConfig makeWithBuilder:^(EMSConfigBuilder *builder) {
                [builder setMobileEngageApplicationCode:@"14C19-A121F"
                                    applicationPassword:@"PaNkfOD90AVpYimMBuZopCpm8OWCrREu"];
                [builder setMerchantId:@"dummyMerchantId"];
                [builder setContactFieldId:@3];
            }];
            [Emarsys setupWithConfig:config];
            XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"waiForResult"];
            [Emarsys setCustomerWithId:@"test@test.com"
                       completionBlock:^(NSError *error) {
                           [expectation fulfill];
                       }];
            [EMSWaiter waitForExpectations:@[expectation]
                                   timeout:5];
        });

        describe(@"Notification Inbox", ^{

            it(@"fetchNotificationsWithResultBlock", ^{
                __block EMSNotificationInboxStatus *_inboxStatus;
                __block NSError *_error;

                [Emarsys.inbox fetchNotificationsWithResultBlock:^(EMSNotificationInboxStatus *inboxStatus, NSError *error) {
                    if (error) {
                        _error = error;

                    } else {
                        _inboxStatus = inboxStatus;
                    }
                }];

                [[_error shouldEventually] beNil];
                [[_inboxStatus shouldNotEventually] beNil];
            });

            it(@"fetchNotificationsWithResultBlock result should contain the gained notification", ^{
                NSString *notificationId = @"210268110.1502804498499608577561.BF04349F-87B6-4CB9-859D-6CDE607F7251";
                NSNumber *inbox = @YES;
                NSDictionary *userInfo = @{
                    @"inbox": inbox,
                    @"u": @{
                        @"deep_link": @"lifestylelabels.com/mobile/product/3245678",
                        @"ems_default_title_unused": @"This is a default title",
                        @"image": @"https://media.giphy.com/media/ktvFa67wmjDEI/giphy.gif",
                        @"sid": @"1d0a_wqdXUl9Vf9NC",
                        @"test_field": @""
                    },
                    @"rootKey": @"rootValue",
                    @"id": notificationId,
                    @"aps": @{
                        @"alert": @"MESS",
                        @"sound": @"default"
                    }
                };

                [Emarsys.push trackMessageOpenWithUserInfo:userInfo];

                __block EMSNotification *returnedNotification;
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [Emarsys.inbox fetchNotificationsWithResultBlock:^(EMSNotificationInboxStatus *inboxStatus, NSError *error) {
                    if (error) {
                        fail(@"error block invoked");
                    } else {
                        for (EMSNotification *noti in inboxStatus.notifications) {
                            if ([noti.id isEqualToString:notificationId]) {
                                returnedNotification = noti;
                                break;
                            }
                        }
                        [exp fulfill];
                    }
                }];

                [EMSWaiter waitForExpectations:@[exp] timeout:30];

                [[returnedNotification shouldNot] beNil];
                [[returnedNotification.id should] equal:notificationId];
            });

            it(@"fetchNotificationsWithResultBlock result should contain the gained notification with title and body", ^{
                NSString *notificationId = @"210268110.1502804498499608577561.BF04349F-87B6-4CB9-859D-6CDE607F7251";
                NSNumber *inbox = @YES;
                NSDictionary *userInfo = @{
                    @"inbox": inbox,
                    @"u": @{
                        @"deep_link": @"lifestylelabels.com/mobile/product/3245678",
                        @"ems_default_title_unused": @"This is a default title",
                        @"image": @"https://media.giphy.com/media/ktvFa67wmjDEI/giphy.gif",
                        @"sid": @"1d0a_wqdXUl9Vf9NC",
                        @"test_field": @""
                    },
                    @"rootKey": @"rootValue",
                    @"id": notificationId,
                    @"aps": @{
                        @"alert": @{
                            @"title": @"title",
                            @"body": @"body"
                        },
                        @"sound": @"default"
                    }
                };

                [Emarsys.push trackMessageOpenWithUserInfo:userInfo];

                __block EMSNotification *returnedNotification;
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"waitForResult"];
                [Emarsys.inbox fetchNotificationsWithResultBlock:^(EMSNotificationInboxStatus *inboxStatus, NSError *error) {
                    if (error) {
                        fail(@"error block invoked");
                    } else {
                        for (EMSNotification *noti in inboxStatus.notifications) {
                            if ([noti.id isEqualToString:notificationId]) {
                                returnedNotification = noti;
                                break;
                            }
                        }
                        [exp fulfill];
                    }
                }];

                [EMSWaiter waitForExpectations:@[exp] timeout:30];

                [[returnedNotification shouldNot] beNil];
                [[returnedNotification.id should] equal:notificationId];
                [[returnedNotification.title should] equal:@"title"];
                [[returnedNotification.body should] equal:@"body"];
            });

            it(@"fetchNotificationsWithResultBlock result should not contain the gained notification", ^{
                NSString *notificationId = @"210268110.1502804498499608577561.BF04349F-87B6-4CB9-859D-6CDE607F7251";
                NSNumber *inbox = @NO;
                NSDictionary *userInfo = @{
                    @"inbox": inbox,
                    @"u": @{
                        @"deep_link": @"lifestylelabels.com/mobile/product/3245678",
                        @"ems_default_title_unused": @"This is a default title",
                        @"image": @"https://media.giphy.com/media/ktvFa67wmjDEI/giphy.gif",
                        @"sid": @"1d0a_wqdXUl9Vf9NC",
                        @"test_field": @""
                    },
                    @"rootKey": @"rootValue",
                    @"id": notificationId,
                    @"aps": @{
                        @"alert": @"MESS",
                        @"sound": @"default"
                    }
                };
                [Emarsys.push trackMessageOpenWithUserInfo:userInfo];

                __block EMSNotificationInboxStatus *resultInboxStatus;
                XCTestExpectation *exp = [[XCTestExpectation alloc] initWithDescription:@"wait"];
                [Emarsys.inbox fetchNotificationsWithResultBlock:^(EMSNotificationInboxStatus *inboxStatus, NSError *error) {
                    if (error) {
                        fail(@"error block invoked");
                    } else {
                        resultInboxStatus = inboxStatus;
                        for (EMSNotification *noti in inboxStatus.notifications) {
                            if ([noti.id isEqualToString:notificationId]) {
                                fail(@"fail");
                            }
                        }
                        [exp fulfill];
                    }
                }];

                [EMSWaiter waitForExpectations:@[exp] timeout:30];

                [[resultInboxStatus shouldNot] beNil];
            });

            it(@"resetBadgeCount", ^{
                __block BOOL _success = NO;
                __block BOOL _error = YES;

                [Emarsys.inbox resetBadgeCountWithCompletionBlock:^(NSError *error) {
                    if (!error) {
                        _success = YES;
                        _error = NO;
                    }
                }];

                [[theValue(_success) shouldNotEventually] beYes];
                [[theValue(_error) shouldEventually] beNo];
            });

        });

SPEC_END
