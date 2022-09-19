//
//  LocationManager.m
//  geolocator
//
//  Created by Maurits van Beusekom on 20/06/2020.
//

#import "GeolocationHandler.h"
#import "GeolocationHandler_Test.h"
#import "../Constants/ErrorCodes.h"

double const kMaxLocationLifeTimeInSeconds = 5.0;

@interface GeolocationHandler() <CLLocationManagerDelegate>

@property(assign, nonatomic) bool isListeningForPositionUpdates;
@property(assign, nonatomic) bool isListeningForSignificantChanges;

@property(strong, nonatomic, nonnull) CLLocationManager *locationManager;

@property(strong, nonatomic) GeolocatorError errorHandler;

@property(strong, nonatomic) GeolocatorResult currentLocationResultHandler;
@property(strong, nonatomic) GeolocatorResult listenerResultHandler;
@property(strong, nonatomic) GeolocatorResult listenerSignificantUpdatesResultHandler;

@end

@implementation GeolocationHandler

- (id) init {
  self = [super init];
  
  if (!self) {
    return nil;
  }
    
  self.isListeningForPositionUpdates = NO;
  self.isListeningForSignificantChanges = NO;
  return self;
}

- (CLLocationManager *) getLocationManager {
  if (!self.locationManager) {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
  }
  return self.locationManager;
}

- (void)setLocationManagerOverride:(CLLocationManager *)locationManager {
  self.locationManager = locationManager;
}

- (CLLocation *)getLastKnownPosition {
  CLLocationManager *locationManager = [self getLocationManager];
  return [locationManager location];
}

- (void)requestPositionWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy
                             resultHandler:(GeolocatorResult _Nonnull)resultHandler
                              errorHandler:(GeolocatorError _Nonnull)errorHandler {
  self.errorHandler = errorHandler;
  self.currentLocationResultHandler = resultHandler;
  
  [self startUpdatingLocationWithDesiredAccuracy:desiredAccuracy
                                  distanceFilter:kCLDistanceFilterNone
               pauseLocationUpdatesAutomatically:NO
                                    activityType:CLActivityTypeOther
                   isListeningForPositionUpdates:self.isListeningForPositionUpdates
                 showBackgroundLocationIndicator:NO];
}

- (void)startListeningWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy
                           distanceFilter:(CLLocationDistance)distanceFilter
        pauseLocationUpdatesAutomatically:(BOOL)pauseLocationUpdatesAutomatically
          showBackgroundLocationIndicator:(BOOL)showBackgroundLocationIndicator
                             activityType:(CLActivityType)activityType
                            resultHandler:(GeolocatorResult _Nonnull )resultHandler
                             errorHandler:(GeolocatorError _Nonnull)errorHandler {
    
  self.errorHandler = errorHandler;
  self.listenerResultHandler = resultHandler;
    
  [self startUpdatingLocationWithDesiredAccuracy:desiredAccuracy
                                  distanceFilter:distanceFilter
               pauseLocationUpdatesAutomatically:pauseLocationUpdatesAutomatically
                                    activityType:activityType
                   isListeningForPositionUpdates:YES
                 showBackgroundLocationIndicator:showBackgroundLocationIndicator];
}

- (void)startListeningForSignificantChanges:(CLLocationAccuracy)desiredAccuracy
        pauseLocationUpdatesAutomatically:(BOOL)pauseLocationUpdatesAutomatically
          showBackgroundLocationIndicator:(BOOL)showBackgroundLocationIndicator
                             activityType:(CLActivityType)activityType
                            resultHandler:(GeolocatorResult _Nonnull )resultHandler
                             errorHandler:(GeolocatorError _Nonnull)errorHandler {
    
  self.errorHandler = errorHandler;
  self.listenerSignificantUpdatesResultHandler = resultHandler;
  self.isListeningForSignificantChanges = YES;
    
  [self startUpdatingSignificantChanges:desiredAccuracy
               pauseLocationUpdatesAutomatically:pauseLocationUpdatesAutomatically
                                    activityType:activityType
                 showBackgroundLocationIndicator:showBackgroundLocationIndicator];
}

- (void)startUpdatingLocationWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy
                                  distanceFilter:(CLLocationDistance)distanceFilter
               pauseLocationUpdatesAutomatically:(BOOL)pauseLocationUpdatesAutomatically
                                    activityType:(CLActivityType)activityType
                   isListeningForPositionUpdates:(BOOL)isListeningForPositionUpdates
                 showBackgroundLocationIndicator:(BOOL)showBackgroundLocationIndicator
                            {
  self.isListeningForPositionUpdates = isListeningForPositionUpdates;
  CLLocationManager *locationManager = [self getLocationManager];
  locationManager.desiredAccuracy = desiredAccuracy;
  locationManager.distanceFilter = distanceFilter;
  if (@available(iOS 6.0, macOS 10.15, *)) {
    locationManager.activityType = activityType;
    locationManager.pausesLocationUpdatesAutomatically = pauseLocationUpdatesAutomatically;
  }
  
#if TARGET_OS_IOS
  if (@available(iOS 9.0, macOS 11.0, *)) {
    locationManager.allowsBackgroundLocationUpdates = [GeolocationHandler shouldEnableBackgroundLocationUpdates];
  }
  if (@available(iOS 11.0, macOS 11.0, *)) {
    locationManager.showsBackgroundLocationIndicator = showBackgroundLocationIndicator;
  }
#endif
  
  [locationManager startUpdatingLocation];
}

- (void)startUpdatingSignificantChanges:(CLLocationAccuracy)desiredAccuracy
               pauseLocationUpdatesAutomatically:(BOOL)pauseLocationUpdatesAutomatically
                                    activityType:(CLActivityType)activityType
                 showBackgroundLocationIndicator:(BOOL)showBackgroundLocationIndicator
                            {
  CLLocationManager *locationManager = [self getLocationManager];
  locationManager.desiredAccuracy = desiredAccuracy;
  if (@available(iOS 6.0, macOS 10.15, *)) {
    locationManager.activityType = activityType;
    locationManager.pausesLocationUpdatesAutomatically = pauseLocationUpdatesAutomatically;
  }
  
#if TARGET_OS_IOS
  if (@available(iOS 9.0, macOS 11.0, *)) {
    locationManager.allowsBackgroundLocationUpdates = [GeolocationHandler shouldEnableBackgroundLocationUpdates];
  }
  if (@available(iOS 11.0, macOS 11.0, *)) {
    locationManager.showsBackgroundLocationIndicator = showBackgroundLocationIndicator;
  }
#endif
  
  [locationManager startMonitoringSignificantLocationChanges];
}

- (void)stopListening {
  [[self getLocationManager] stopUpdatingLocation];
  self.isListeningForPositionUpdates = NO;
  self.errorHandler = nil;
  self.listenerResultHandler = nil;
  if (self.isListeningForSignificantChanges) {
    [[self getLocationManager] stopMonitoringSignificantLocationChanges];
    self.isListeningForSignificantChanges = NO;
    self.listenerSignificantUpdatesResultHandler = nil;
  }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
  if (
    !self.listenerResultHandler && 
    !self.currentLocationResultHandler && 
    !self.listenerSignificantUpdatesResultHandler) return;

  CLLocation *mostRecentLocation = [locations lastObject];
  NSTimeInterval ageInSeconds = -[mostRecentLocation.timestamp timeIntervalSinceNow];
  // If location is older then 5.0 seconds it is likely a cached location which
  // will be skipped.
  if (!self.isListeningForPositionUpdates && ageInSeconds > kMaxLocationLifeTimeInSeconds) {
    return;
  }
    
  if ([locations lastObject]) {
      if (self.currentLocationResultHandler != nil) {
          self.currentLocationResultHandler(mostRecentLocation);
      }
      if (self.listenerResultHandler != nil) {
          self.listenerResultHandler(mostRecentLocation);
      }
      if (self.listenerSignificantUpdatesResultHandler != nil) {
        self.listenerSignificantUpdatesResultHandler(mostRecentLocation);
      }
  }

  self.currentLocationResultHandler = nil;
  if (!self.isListeningForPositionUpdates && !self.isListeningForSignificantChanges) {
    [self stopListening];
  }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(nonnull NSError *)error {
  NSLog(@"LOCATION UPDATE FAILURE:"
        "Error reason: %@"
        "Error description: %@", error.localizedFailureReason, error.localizedDescription);
  
  if([error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorLocationUnknown) {
    return;
  }
  
  if (self.errorHandler) {
    self.errorHandler(GeolocatorErrorLocationUpdateFailure, error.localizedDescription);
  }
  
  self.currentLocationResultHandler = nil;
  if (!self.isListeningForPositionUpdates && !self.isListeningForSignificantChanges) {
    [self stopListening];
  }
}

+ (BOOL) shouldEnableBackgroundLocationUpdates {
  if (@available(iOS 9.0, *)) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"UIBackgroundModes"] containsObject: @"location"];
  } else {
    return NO;
  }
}
@end
