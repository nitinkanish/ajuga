import CoreLocation
import CoreMotion
import EventKit
import Flutter
import Foundation
import HealthKit
import MapKit
import UIKit
import UserNotifications

/// Native bridge for HealthKit, Core Motion, Core Location, barometer, and
/// local outdoor-session persistence. Registered from AppDelegate.
final class ActivityPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  static let channelName = "aster/activity"
  static let eventName = "aster/activity_events"

  private var channel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?

  private let healthStore = HKHealthStore()
  private let pedometer = CMPedometer()
  private let altimeter = CMAltimeter()
  private let locationManager = CLLocationManager()
  private let motionActivity = CMMotionActivityManager()
  private let eventStore = EKEventStore()

  private var isTracking = false
  private var isPaused = false
  private var relativeAltitudeDeltas: [Double] = []
  private var lastRelativeAltitude: Double?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ActivityPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)

    let events = FlutterEventChannel(
      name: eventName,
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)

    registrar.register(
      RouteMapViewFactory(messenger: registrar.messenger()),
      withId: "aster/route_map"
    )
    ThermalBridge.register(messenger: registrar.messenger())
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "platformInfo":
      result([
        "healthKitAvailable": HKHealthStore.isHealthDataAvailable(),
        "pedometerAvailable": CMPedometer.isStepCountingAvailable(),
        "altimeterAvailable": CMAltimeter.isRelativeAltitudeAvailable(),
        "locationServicesEnabled": CLLocationManager.locationServicesEnabled(),
      ])
    case "requestHealthAuthorization":
      requestHealthAuthorization(result: result)
    case "requestMotionAuthorization":
      requestMotionAuthorization(result: result)
    case "requestLocationAuthorization":
      let always = (call.arguments as? [String: Any])?["always"] as? Bool ?? false
      requestLocationAuthorization(always: always, result: result)
    case "getDailyActivity":
      let args = call.arguments as? [String: Any] ?? [:]
      let dayMs = args["dayEpochMs"] as? Int64
      getDailyActivity(dayEpochMs: dayMs, result: result)
    case "getWeeklySteps":
      getWeeklySteps(result: result)
    case "getMonthlySteps":
      getMonthlySteps(result: result)
    case "getHistory":
      let days = (call.arguments as? [String: Any])?["days"] as? Int ?? 30
      getHistory(days: days, result: result)
    case "startOutdoorSession":
      startOutdoorSession(result: result)
    case "pauseOutdoorSession":
      pauseOutdoorSession(result: result)
    case "resumeOutdoorSession":
      resumeOutdoorSession(result: result)
    case "stopOutdoorSession":
      stopOutdoorSession(result: result)
    case "saveSession":
      saveSession(arguments: call.arguments, result: result)
    case "loadSessions":
      loadSessions(result: result)
    case "loadSession":
      let id = (call.arguments as? [String: Any])?["id"] as? String
      loadSession(id: id, result: result)
    case "deleteSession":
      let id = (call.arguments as? [String: Any])?["id"] as? String
      deleteSession(id: id, result: result)
    case "getLifeSignals":
      getLifeSignals(result: result)
    case "requestCalendarAccess":
      requestCalendarAccess(result: result)
    case "todayEvents":
      todayEvents(result: result)
    case "requestNotificationAuthorization":
      requestNotificationAuthorization(result: result)
    case "scheduleNotification":
      scheduleNotification(arguments: call.arguments, result: result)
    case "cancelNotification":
      let id = (call.arguments as? [String: Any])?["id"] as? String
      cancelNotification(id: id, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - HealthKit

  private var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = []
    let identifiers: [HKQuantityTypeIdentifier] = [
      .stepCount,
      .distanceWalkingRunning,
      .flightsClimbed,
      .appleExerciseTime,
      .walkingSpeed,
      .walkingStepLength,
      .walkingAsymmetryPercentage,
      .walkingDoubleSupportPercentage,
    ]
    for id in identifiers {
      if let type = HKObjectType.quantityType(forIdentifier: id) {
        types.insert(type)
      }
    }
    types.insert(HKObjectType.workoutType())
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleep)
    }
    if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(energy)
    }
    return types
  }

  private func requestHealthAuthorization(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(["status": "unavailable"])
      return
    }
    healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
      DispatchQueue.main.async {
        if let error {
          // Missing HealthKit entitlement must not block Core Motion.
          result([
            "status": "unavailable",
            "message": error.localizedDescription,
          ])
        } else {
          // HealthKit does not reveal whether read access was granted.
          result(["status": success ? "requested" : "failed"])
        }
      }
    }
  }

  private func requestMotionAuthorization(result: @escaping FlutterResult) {
    guard CMPedometer.isStepCountingAvailable() else {
      result(["status": "unavailable"])
      return
    }
    // Querying today triggers the Motion & Fitness prompt on first use.
    let start = Calendar.current.startOfDay(for: Date())
    pedometer.queryPedometerData(from: start, to: Date()) { data, error in
      DispatchQueue.main.async {
        if let error {
          result(["status": "denied_or_error", "message": error.localizedDescription])
        } else {
          result([
            "status": "authorized",
            "steps": data?.numberOfSteps.intValue as Any,
            "distance": data?.distance?.doubleValue as Any,
          ])
        }
      }
    }
  }

  private func requestLocationAuthorization(always: Bool, result: @escaping FlutterResult) {
    locationManager.delegate = self
    pendingLocationResult = result
    if always {
      locationManager.requestAlwaysAuthorization()
    } else {
      locationManager.requestWhenInUseAuthorization()
    }
    // If already determined, respond immediately.
    let status = locationManager.authorizationStatus
    if status != .notDetermined {
      pendingLocationResult = nil
      result(["status": Self.authStatusString(status)])
    }
  }

  private var pendingLocationResult: FlutterResult?

  private static func authStatusString(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedAlways: return "authorizedAlways"
    case .authorizedWhenInUse: return "authorizedWhenInUse"
    @unknown default: return "unknown"
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let pendingLocationResult else { return }
    let status = manager.authorizationStatus
    if status != .notDetermined {
      self.pendingLocationResult = nil
      pendingLocationResult(["status": Self.authStatusString(status)])
    }
  }

  // MARK: - Daily activity queries

  private func dayInterval(dayEpochMs: Int64?) -> DateInterval {
    let calendar = Calendar.current
    let day: Date
    if let dayEpochMs {
      day = Date(timeIntervalSince1970: TimeInterval(dayEpochMs) / 1000.0)
    } else {
      day = Date()
    }
    let start = calendar.startOfDay(for: day)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
    return DateInterval(start: start, end: end)
  }

  private func getDailyActivity(dayEpochMs: Int64?, result: @escaping FlutterResult) {
    let interval = dayInterval(dayEpochMs: dayEpochMs)
    var payload: [String: Any] = [
      "dayStartEpochMs": Int64(interval.start.timeIntervalSince1970 * 1000),
      "updatedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
    ]

    let group = DispatchGroup()

    func quantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, key: String) {
      guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
      group.enter()
      let predicate = HKQuery.predicateForSamples(
        withStart: interval.start,
        end: interval.end,
        options: .strictStartDate
      )
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, stats, _ in
        let value = stats?.sumQuantity()?.doubleValue(for: unit)
        DispatchQueue.main.async {
          if let value { payload[key] = value }
          group.leave()
        }
      }
      healthStore.execute(query)
    }

    func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, key: String) {
      guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
      group.enter()
      let predicate = HKQuery.predicateForSamples(
        withStart: interval.start,
        end: interval.end,
        options: .strictStartDate
      )
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .discreteAverage
      ) { _, stats, _ in
        let value = stats?.averageQuantity()?.doubleValue(for: unit)
        DispatchQueue.main.async {
          if let value { payload[key] = value }
          group.leave()
        }
      }
      healthStore.execute(query)
    }

    if HKHealthStore.isHealthDataAvailable() {
      quantity(.stepCount, unit: .count(), key: "hkSteps")
      quantity(.distanceWalkingRunning, unit: .meter(), key: "hkDistanceMeters")
      quantity(.flightsClimbed, unit: .count(), key: "hkFlights")
      quantity(.appleExerciseTime, unit: .minute(), key: "hkExerciseMinutes")
      average(.walkingSpeed, unit: HKUnit.meter().unitDivided(by: .second()), key: "hkWalkingSpeedMps")
      average(.walkingStepLength, unit: .meter(), key: "hkStepLengthMeters")
      average(.walkingAsymmetryPercentage, unit: .percent(), key: "hkWalkingAsymmetry")
      average(.walkingDoubleSupportPercentage, unit: .percent(), key: "hkDoubleSupport")
    }

    if CMPedometer.isStepCountingAvailable() {
      group.enter()
      pedometer.queryPedometerData(from: interval.start, to: min(interval.end, Date())) { data, _ in
        DispatchQueue.main.async {
          if let data {
            payload["cmSteps"] = data.numberOfSteps.intValue
            if let distance = data.distance?.doubleValue {
              payload["cmDistanceMeters"] = distance
            }
            if let cadence = data.currentCadence?.doubleValue {
              payload["cmCadence"] = cadence
            }
          }
          group.leave()
        }
      }
    }

    var didFinish = false
    func finish() {
      guard !didFinish else { return }
      didFinish = true
      // Reconciliation: HealthKit is source of truth when present.
      if let hk = payload["hkSteps"] as? Double {
        payload["steps"] = Int(hk.rounded())
        payload["source"] = "HealthKit"
      } else if let cm = payload["cmSteps"] as? Int {
        payload["steps"] = cm
        payload["source"] = "Core Motion"
      } else {
        payload["source"] = "unavailable"
      }

      if let hk = payload["hkDistanceMeters"] as? Double {
        payload["distanceMeters"] = hk
        if payload["source"] as? String == "unavailable" {
          payload["source"] = "HealthKit"
        }
      } else if let cm = payload["cmDistanceMeters"] as? Double {
        payload["distanceMeters"] = cm
        if payload["source"] as? String == "unavailable" {
          payload["source"] = "Core Motion"
        }
      }

      result(payload)
    }

    group.notify(queue: .main, execute: finish)
    // Health queries can stall when the HealthKit entitlement is missing.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: finish)
  }

  private func getWeeklySteps(result: @escaping FlutterResult) {
    statisticsCollection(days: 7, result: result)
  }

  private func getMonthlySteps(result: @escaping FlutterResult) {
    statisticsCollection(days: 30, result: result)
  }

  private func getHistory(days: Int, result: @escaping FlutterResult) {
    statisticsCollection(days: days, result: result)
  }

  private func statisticsCollection(days: Int, result: @escaping FlutterResult) {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
          HKHealthStore.isHealthDataAvailable()
    else {
      pedometerHistory(days: days, result: result)
      return
    }
    let calendar = Calendar.current
    let end = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
    guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date()))
    else {
      pedometerHistory(days: days, result: result)
      return
    }
    var interval = DateComponents()
    interval.day = 1
    let query = HKStatisticsCollectionQuery(
      quantityType: stepType,
      quantitySamplePredicate: nil,
      options: .cumulativeSum,
      anchorDate: start,
      intervalComponents: interval
    )
    var didFinish = false
    func finishHealth(_ rows: [[String: Any]]) {
      guard !didFinish else { return }
      didFinish = true
      result(["days": rows, "source": "HealthKit"])
    }
    query.initialResultsHandler = { _, collection, error in
      var rows: [[String: Any]] = []
      var missingSample = error != nil || collection == nil
      collection?.enumerateStatistics(from: start, to: end) { stats, _ in
        guard let steps = stats.sumQuantity()?.doubleValue(for: .count()) else {
          missingSample = true
          return
        }
        rows.append([
          "dayStartEpochMs": Int64(stats.startDate.timeIntervalSince1970 * 1000),
          "steps": Int(steps.rounded()),
        ])
      }
      DispatchQueue.main.async {
        if missingSample || rows.isEmpty {
          guard !didFinish else { return }
          didFinish = true
          self.pedometerHistory(days: days, result: result)
        } else {
          finishHealth(rows)
        }
      }
    }
    healthStore.execute(query)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      guard !didFinish else { return }
      didFinish = true
      self.pedometerHistory(days: days, result: result)
    }
  }

  /// Core Motion keeps about seven days of step history. Used when HealthKit has no sample.
  private func pedometerHistory(days: Int, result: @escaping FlutterResult) {
    guard CMPedometer.isStepCountingAvailable() else {
      result(["days": [], "source": "unavailable"])
      return
    }
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let count = min(max(days, 1), 7)
    let group = DispatchGroup()
    var rows: [[String: Any]] = []
    let lock = NSLock()
    for offset in 0..<count {
      guard let start = calendar.date(byAdding: .day, value: -(count - 1 - offset), to: todayStart) else {
        continue
      }
      let end = min(calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400), Date())
      group.enter()
      pedometer.queryPedometerData(from: start, to: end) { data, _ in
        let steps = data?.numberOfSteps.intValue ?? 0
        lock.lock()
        rows.append([
          "dayStartEpochMs": Int64(start.timeIntervalSince1970 * 1000),
          "steps": steps,
        ])
        lock.unlock()
        group.leave()
      }
    }
    var didFinish = false
    func finish() {
      guard !didFinish else { return }
      didFinish = true
      lock.lock()
      let snapshot = rows
      lock.unlock()
      let ordered = snapshot.sorted { left, right in
        let a = (left["dayStartEpochMs"] as? NSNumber)?.int64Value ?? 0
        let b = (right["dayStartEpochMs"] as? NSNumber)?.int64Value ?? 0
        return a < b
      }
      result(["days": ordered, "source": "Core Motion"])
    }
    group.notify(queue: .main, execute: finish)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: finish)
  }

  // MARK: - Outdoor tracking

  private func startOutdoorSession(result: @escaping FlutterResult) {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.activityType = .fitness
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.showsBackgroundLocationIndicator = true

    relativeAltitudeDeltas = []
    lastRelativeAltitude = nil
    isPaused = false
    isTracking = true

    locationManager.startUpdatingLocation()
    locationManager.startUpdatingHeading()

    if CMAltimeter.isRelativeAltitudeAvailable() {
      altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
        guard let self, let data, self.isTracking, !self.isPaused else { return }
        let relative = data.relativeAltitude.doubleValue
        if let last = self.lastRelativeAltitude {
          self.relativeAltitudeDeltas.append(relative - last)
        }
        self.lastRelativeAltitude = relative
        self.emit([
          "type": "altitude",
          "relativeAltitude": relative,
          "deltas": self.relativeAltitudeDeltas,
        ])
      }
    }

    result([
      "status": "tracking",
      "startedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
    ])
  }

  private func pauseOutdoorSession(result: @escaping FlutterResult) {
    isPaused = true
    locationManager.stopUpdatingLocation()
    locationManager.stopUpdatingHeading()
    altimeter.stopRelativeAltitudeUpdates()
    result(["status": "paused"])
  }

  private func resumeOutdoorSession(result: @escaping FlutterResult) {
    isPaused = false
    isTracking = true
    locationManager.startUpdatingLocation()
    locationManager.startUpdatingHeading()
    if CMAltimeter.isRelativeAltitudeAvailable() {
      altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
        guard let self, let data, self.isTracking, !self.isPaused else { return }
        let relative = data.relativeAltitude.doubleValue
        if let last = self.lastRelativeAltitude {
          self.relativeAltitudeDeltas.append(relative - last)
        }
        self.lastRelativeAltitude = relative
        self.emit([
          "type": "altitude",
          "relativeAltitude": relative,
          "deltas": self.relativeAltitudeDeltas,
        ])
      }
    }
    result(["status": "tracking"])
  }

  private func stopOutdoorSession(result: @escaping FlutterResult) {
    isTracking = false
    isPaused = false
    locationManager.stopUpdatingLocation()
    locationManager.stopUpdatingHeading()
    locationManager.allowsBackgroundLocationUpdates = false
    altimeter.stopRelativeAltitudeUpdates()
    result([
      "status": "stopped",
      "relativeAltitudeDeltas": relativeAltitudeDeltas,
      "stoppedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
    ])
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard isTracking, !isPaused else { return }
    for location in locations {
      emit([
        "type": "location",
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
        "altitude": location.altitude,
        "horizontalAccuracy": location.horizontalAccuracy,
        "speed": location.speed,
        "course": location.course,
        "timestampEpochMs": Int64(location.timestamp.timeIntervalSince1970 * 1000),
      ])
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard isTracking, !isPaused else { return }
    emit([
      "type": "heading",
      "trueHeading": newHeading.trueHeading,
      "magneticHeading": newHeading.magneticHeading,
      "accuracy": newHeading.headingAccuracy,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    emit(["type": "error", "message": error.localizedDescription])
  }

  private func emit(_ payload: [String: Any]) {
    eventSink?(payload)
  }

  // MARK: - Local session store

  private var sessionsDirectory: URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("outdoor_sessions", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func saveSession(arguments: Any?, result: @escaping FlutterResult) {
    guard let json = arguments as? String,
          let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = object["id"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "Expected session JSON string", details: nil))
      return
    }
    let url = sessionsDirectory.appendingPathComponent("\(id).json")
    do {
      try data.write(to: url, options: .atomic)
      result(["status": "saved", "id": id])
    } catch {
      result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
    }
  }

  private func loadSessions(result: @escaping FlutterResult) {
    let files = (try? FileManager.default.contentsOfDirectory(
      at: sessionsDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey]
    )) ?? []
    var sessions: [[String: Any]] = []
    for file in files where file.pathExtension == "json" {
      if let data = try? Data(contentsOf: file),
         let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      {
        // History list omits heavy route arrays when huge; still return full file for now.
        sessions.append(object)
      }
    }
    sessions.sort {
      let a = ($0["finishedAtEpochMs"] as? Int64) ?? ($0["startedAtEpochMs"] as? Int64) ?? 0
      let b = ($1["finishedAtEpochMs"] as? Int64) ?? ($1["startedAtEpochMs"] as? Int64) ?? 0
      return a > b
    }
    if let data = try? JSONSerialization.data(withJSONObject: sessions),
       let json = String(data: data, encoding: .utf8)
    {
      result(json)
    } else {
      result("[]")
    }
  }

  private func loadSession(id: String?, result: @escaping FlutterResult) {
    guard let id else {
      result(FlutterError(code: "bad_args", message: "Missing id", details: nil))
      return
    }
    let url = sessionsDirectory.appendingPathComponent("\(id).json")
    if let data = try? Data(contentsOf: url), let json = String(data: data, encoding: .utf8) {
      result(json)
    } else {
      result(nil)
    }
  }

  private func deleteSession(id: String?, result: @escaping FlutterResult) {
    guard let id else {
      result(FlutterError(code: "bad_args", message: "Missing id", details: nil))
      return
    }
    let url = sessionsDirectory.appendingPathComponent("\(id).json")
    try? FileManager.default.removeItem(at: url)
    result(["status": "deleted"])
  }
}

extension ActivityPlugin {
  func getLifeSignals(result: @escaping FlutterResult) {
    let interval = dayInterval(dayEpochMs: nil)
    var payload: [String: Any] = [
      "healthStatus": HKHealthStore.isHealthDataAvailable() ? "queried" : "unavailable",
      "motionStatus": CMMotionActivityManager.isActivityAvailable() ? "ok" : "unavailable",
    ]
    let group = DispatchGroup()
    var didFinish = false

    if HKHealthStore.isHealthDataAvailable(),
       let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      group.enter()
      let calendar = Calendar.current
      let windowStart = calendar.date(byAdding: .hour, value: -6, to: interval.start) ?? interval.start
      let windowEnd = calendar.date(byAdding: .hour, value: 12, to: interval.start) ?? interval.end
      let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])
      let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
        DispatchQueue.main.async {
          if error == nil, let categories = samples as? [HKCategorySample] {
            if let minutes = self.mergedAsleepMinutes(categories) {
              payload["sleepMinutes"] = minutes
              payload["sleepSource"] = "HealthKit"
            }
          }
          group.leave()
        }
      }
      healthStore.execute(query)
    }

    if HKHealthStore.isHealthDataAvailable(),
       let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      group.enter()
      let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
      let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
        DispatchQueue.main.async {
          if error == nil, let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            payload["activeEnergyKcal"] = kcal
          }
          group.leave()
        }
      }
      healthStore.execute(query)
    }

    if HKHealthStore.isHealthDataAvailable() {
      group.enter()
      let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
      let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 20, sortDescriptors: nil) { _, samples, error in
        DispatchQueue.main.async {
          if error == nil, let workouts = samples as? [HKWorkout] {
            payload["workouts"] = workouts.map { workout -> [String: Any] in
              [
                "id": workout.uuid.uuidString,
                "title": Self.workoutName(workout.workoutActivityType),
                "startEpochMs": Int64(workout.startDate.timeIntervalSince1970 * 1000),
                "endEpochMs": Int64(workout.endDate.timeIntervalSince1970 * 1000),
              ]
            }
          }
          group.leave()
        }
      }
      healthStore.execute(query)
    }

    if CMMotionActivityManager.isActivityAvailable() {
      group.enter()
      motionActivity.queryActivityStarting(from: interval.start, to: min(interval.end, Date()), to: OperationQueue()) { activities, error in
        DispatchQueue.main.async {
          if error != nil {
            payload["motionStatus"] = "unavailable"
          } else if let activities {
            payload["motionSegments"] = self.compactMotion(activities)
          }
          group.leave()
        }
      }
    }

    func finish() {
      guard !didFinish else { return }
      didFinish = true
      result(payload)
    }
    group.notify(queue: .main, execute: finish)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: finish)
  }

  func mergedAsleepMinutes(_ samples: [HKCategorySample]) -> Int? {
    var asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleep.rawValue]
    if #available(iOS 16.0, *) {
      asleep.insert(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
      asleep.insert(HKCategoryValueSleepAnalysis.asleepCore.rawValue)
      asleep.insert(HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
      asleep.insert(HKCategoryValueSleepAnalysis.asleepREM.rawValue)
    }
    let spans = samples.compactMap { sample -> (Date, Date)? in
      guard asleep.contains(sample.value), sample.endDate > sample.startDate else { return nil }
      return (sample.startDate, sample.endDate)
    }.sorted { $0.0 < $1.0 }
    guard let first = spans.first else { return nil }
    var start = first.0
    var end = first.1
    var total: TimeInterval = 0
    for span in spans.dropFirst() {
      if span.0 <= end {
        if span.1 > end { end = span.1 }
      } else {
        total += end.timeIntervalSince(start)
        start = span.0
        end = span.1
      }
    }
    total += end.timeIntervalSince(start)
    return Int(total / 60.0)
  }

  func compactMotion(_ activities: [CMMotionActivity]) -> [[String: Any]] {
    let sorted = activities.sorted { $0.startDate < $1.startDate }
    var rows: [[String: Any]] = []
    for activity in sorted {
      let name = Self.motionName(activity)
      guard let name else { continue }
      let confidence: String
      switch activity.confidence {
      case .low: confidence = "low"
      case .medium: confidence = "medium"
      case .high: confidence = "high"
      @unknown default: confidence = "unknown"
      }
      let detail = "Confidence: \(confidence). This classification does not describe what you were doing."
      if var last = rows.last,
         last["title"] as? String == name,
         let endMs = last["endEpochMs"] as? Int64,
         activity.startDate.timeIntervalSince1970 * 1000 - Double(endMs) < 90_000 {
        last["endEpochMs"] = Int64(activity.startDate.timeIntervalSince1970 * 1000)
        rows[rows.count - 1] = last
      } else {
        rows.append([
          "id": "\(activity.startDate.timeIntervalSince1970)",
          "title": name,
          "detail": detail,
          "startEpochMs": Int64(activity.startDate.timeIntervalSince1970 * 1000),
          "endEpochMs": Int64(activity.startDate.timeIntervalSince1970 * 1000),
        ])
      }
    }
    return rows
  }

  static func motionName(_ activity: CMMotionActivity) -> String? {
    if activity.walking { return "walking" }
    if activity.running { return "running" }
    if activity.cycling { return "cycling" }
    if activity.automotive { return "automotive" }
    if activity.stationary { return "stationary" }
    return nil
  }

  static func workoutName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "Run"
    case .walking: return "Walk"
    case .cycling: return "Ride"
    case .hiking: return "Hike"
    case .yoga: return "Yoga"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
    default: return "Workout"
    }
  }

  func requestCalendarAccess(result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { granted, error in
        DispatchQueue.main.async {
          result([
            "status": granted ? "authorized" : "denied",
            "message": error?.localizedDescription as Any,
          ])
        }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, error in
        DispatchQueue.main.async {
          result([
            "status": granted ? "authorized" : "denied",
            "message": error?.localizedDescription as Any,
          ])
        }
      }
    }
  }

  func todayEvents(result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .event)
    let allowed: Bool
    if #available(iOS 17.0, *) {
      allowed = status == .fullAccess || status == .authorized
    } else {
      allowed = status == .authorized
    }
    guard allowed else {
      result(["status": "denied", "events": []])
      return
    }
    let interval = dayInterval(dayEpochMs: nil)
    let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
    let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    let rows: [[String: Any]] = events.prefix(40).map { event in
      [
        "id": event.eventIdentifier ?? UUID().uuidString,
        "title": event.title ?? "Busy",
        "startEpochMs": Int64(event.startDate.timeIntervalSince1970 * 1000),
        "endEpochMs": Int64(event.endDate.timeIntervalSince1970 * 1000),
        "calendar": event.calendar.title,
      ]
    }
    result(["status": "authorized", "events": rows])
  }

  func requestNotificationAuthorization(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
      DispatchQueue.main.async {
        result(["granted": granted])
      }
    }
  }

  func scheduleNotification(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let id = args["id"] as? String,
          let title = args["title"] as? String,
          let body = args["body"] as? String
    else {
      result(["status": "bad_args"])
      return
    }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    let repeats = args["repeatsWeekly"] as? Bool ?? false
    let trigger: UNNotificationTrigger
    if repeats {
      var components = DateComponents()
      components.hour = args["hour"] as? Int
      components.minute = args["minute"] as? Int
      if let weekday = args["weekday"] as? Int {
        components.weekday = weekday == 7 ? 1 : weekday + 1
      }
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    } else {
      let epoch = (args["epochMs"] as? NSNumber)?.doubleValue ?? 0
      let fire = Date(timeIntervalSince1970: epoch / 1000.0)
      let interval = max(1, fire.timeIntervalSinceNow)
      trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    }
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { _ in
      DispatchQueue.main.async { result(["status": "scheduled"]) }
    }
  }

  func cancelNotification(id: String?, result: @escaping FlutterResult) {
    guard let id else {
      result(["status": "bad_args"])
      return
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    result(["status": "cancelled"])
  }
}

extension ActivityPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

// MARK: - MapKit platform view

final class RouteMapViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    RouteMapView(frame: frame, viewId: viewId, args: args as? [String: Any], messenger: messenger)
  }
}

final class RouteMapView: NSObject, FlutterPlatformView {
  private let mapView: MKMapView
  private let channel: FlutterMethodChannel
  private var polyline: MKPolyline?

  init(frame: CGRect, viewId: Int64, args: [String: Any]?, messenger: FlutterBinaryMessenger) {
    mapView = MKMapView(frame: frame)
    mapView.showsUserLocation = true
    mapView.userTrackingMode = .follow
    channel = FlutterMethodChannel(name: "aster/route_map_\(viewId)", binaryMessenger: messenger)
    super.init()
    mapView.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    if let coords = args?["coordinates"] as? [[String: Double]] {
      updateRoute(coords)
    }
  }

  func view() -> UIView { mapView }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setRoute":
      let coords = (call.arguments as? [String: Any])?["coordinates"] as? [[String: Double]] ?? []
      updateRoute(coords)
      result(nil)
    case "followUser":
      let follow = (call.arguments as? [String: Any])?["follow"] as? Bool ?? true
      mapView.userTrackingMode = follow ? .follow : .none
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func updateRoute(_ coords: [[String: Double]]) {
    if let polyline {
      mapView.removeOverlay(polyline)
    }
    guard coords.count >= 2 else { return }
    var points = coords.compactMap { item -> CLLocationCoordinate2D? in
      guard let lat = item["lat"], let lon = item["lon"] else { return nil }
      return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    let line = MKPolyline(coordinates: &points, count: points.count)
    polyline = line
    mapView.addOverlay(line)
    mapView.setVisibleMapRect(
      line.boundingMapRect,
      edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
      animated: true
    )
  }
}

extension RouteMapView: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polyline = overlay as? MKPolyline {
      let renderer = MKPolylineRenderer(polyline: polyline)
      renderer.strokeColor = UIColor(red: 0.18, green: 0.42, blue: 0.95, alpha: 1)
      renderer.lineWidth = 4
      return renderer
    }
    return MKOverlayRenderer(overlay: overlay)
  }
}

private struct ProcTaskInfo {
  var virtualSize: UInt64 = 0
  var residentSize: UInt64 = 0
  var totalUser: UInt64 = 0
  var totalSystem: UInt64 = 0
  var threadsUser: UInt64 = 0
  var threadsSystem: UInt64 = 0
  var policy: Int32 = 0
  var faults: Int32 = 0
  var pageins: Int32 = 0
  var cowFaults: Int32 = 0
  var messagesSent: Int32 = 0
  var messagesReceived: Int32 = 0
  var syscallsMach: Int32 = 0
  var syscallsUnix: Int32 = 0
  var csw: Int32 = 0
  var threadNum: Int32 = 0
  var numRunning: Int32 = 0
  var priority: Int32 = 0
}

@_silgen_name("proc_listallpids")
private func proc_listallpids(_ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_name")
private func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(
  _ pid: Int32,
  _ flavor: Int32,
  _ arg: UInt64,
  _ buffer: UnsafeMutableRawPointer?,
  _ buffersize: Int32
) -> Int32

final class ThermalBridge: NSObject, FlutterStreamHandler {
  static let shared = ThermalBridge()

  private var channel: FlutterMethodChannel?
  private var events: FlutterEventChannel?
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  static func register(messenger: FlutterBinaryMessenger) {
    let bridge = ThermalBridge.shared
    let channel = FlutterMethodChannel(name: "aster/thermal", binaryMessenger: messenger)
    bridge.channel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "getThermalState" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(bridge.payload())
    }
    let events = FlutterEventChannel(name: "aster/thermal_events", binaryMessenger: messenger)
    bridge.events = events
    events.setStreamHandler(bridge)
    bridge.start()
  }

  func start() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit()
    }
  }

  private var lastCpuTicks: (Double, Double, Double, Double)?
  private var lastTaskCpuSeconds: Double?
  private var lastTaskAt: Date?
  private var iokitHandle: UnsafeMutableRawPointer?
  private var previousProcessCpu: [Int32: UInt64] = [:]
  private var lastProcessAt: Date?

  func payload() -> [String: Any] {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let cpu = cpuFractions()
    var payload: [String: Any] = [
      "state": Self.name(ProcessInfo.processInfo.thermalState),
      "capturedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
      "battery": Self.batteryName(UIDevice.current.batteryState),
      "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
    ]
    let level = UIDevice.current.batteryLevel
    if level >= 0 {
      payload["batteryLevel"] = Double(level)
    }
    if let system = cpu.system {
      payload["systemCpu"] = system
    }
    if let ajuga = cpu.ajuga {
      payload["ajugaCpu"] = ajuga
    }
    if let temp = batteryCelsius() {
      payload["tempC"] = temp
    }
    let apps = runningApps()
    if !apps.isEmpty {
      payload["apps"] = apps
    }
    return payload
  }

  func runningApps() -> [[String: Any]] {
    let byteCount = proc_listallpids(nil, 0)
    guard byteCount > 0 else { return [] }
    var pids = [Int32](repeating: 0, count: Int(byteCount) / MemoryLayout<Int32>.size + 32)
    let written = pids.withUnsafeMutableBytes { raw -> Int32 in
      guard let base = raw.baseAddress else { return 0 }
      return proc_listallpids(base, Int32(raw.count))
    }
    let count = max(0, min(pids.count, Int(written) / MemoryLayout<Int32>.size))
    let now = Date()
    let elapsed = lastProcessAt.map { now.timeIntervalSince($0) } ?? 0
    var nextCpu: [Int32: UInt64] = [:]
    var rows: [[String: Any]] = []
    let selfPid = Int32(getpid())
    for pid in pids.prefix(count) where pid > 0 {
      var info = ProcTaskInfo()
      let size = withUnsafeMutableBytes(of: &info) { raw -> Int32 in
        proc_pidinfo(pid, 4, 0, raw.baseAddress, Int32(MemoryLayout<ProcTaskInfo>.size))
      }
      guard size >= 32 else { continue }
      let total = info.totalUser &+ info.totalSystem
      nextCpu[pid] = total
      guard elapsed > 0.4, let previous = previousProcessCpu[pid], total >= previous else { continue }
      let cpu = Double(total - previous) / 1_000_000_000.0 / elapsed
      guard cpu >= 0.04 else { continue }
      var nameBytes = [CChar](repeating: 0, count: 256)
      let nameLength = nameBytes.withUnsafeMutableBytes { raw -> Int32 in
        proc_name(pid, raw.baseAddress, UInt32(raw.count))
      }
      let rawName = nameLength > 0 ? String(cString: nameBytes) : ""
      guard !rawName.isEmpty else { continue }
      let isAjuga = pid == selfPid || rawName == "Runner"
      rows.append([
        "name": Self.friendlyAppName(rawName, isAjuga: isAjuga),
        "cpu": min(cpu, 8),
        "isAjuga": isAjuga,
      ])
    }
    previousProcessCpu = nextCpu
    lastProcessAt = now
    rows.sort { (($0["cpu"] as? Double) ?? 0) > (($1["cpu"] as? Double) ?? 0) }
    if rows.count > 8 {
      return Array(rows.prefix(8))
    }
    return rows
  }

  static func friendlyAppName(_ name: String, isAjuga: Bool) -> String {
    if isAjuga { return "Ajuga" }
    switch name {
    case "MobileSafari": return "Safari"
    case "SpringBoard": return "Home Screen"
    case "MobileSMS": return "Messages"
    case "MobileMail": return "Mail"
    case "MobileCal": return "Calendar"
    case "Camera": return "Camera"
    case "Maps": return "Maps"
    case "Music": return "Music"
    case "Podcasts": return "Podcasts"
    case "mediaserverd": return "Video and audio"
    case "backboardd": return "Display"
    case "runningboardd": return "App switching"
    case "locationd": return "Location"
    case "wifid": return "Wi-Fi"
    default: return name
    }
  }

  func cpuFractions() -> (system: Double?, ajuga: Double?) {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
    let hostResult = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
      }
    }
    var systemFraction: Double?
    if hostResult == KERN_SUCCESS {
      let ticks = (
        Double(info.cpu_ticks.0),
        Double(info.cpu_ticks.1),
        Double(info.cpu_ticks.2),
        Double(info.cpu_ticks.3)
      )
      if let previous = lastCpuTicks {
        let user = max(0, ticks.0 - previous.0)
        let system = max(0, ticks.1 - previous.1)
        let idle = max(0, ticks.2 - previous.2)
        let nice = max(0, ticks.3 - previous.3)
        let total = user + system + idle + nice
        if total > 0 {
          systemFraction = (user + system + nice) / total
        }
      }
      lastCpuTicks = ticks
    }

    var taskInfo = task_thread_times_info_data_t()
    var taskCount = mach_msg_type_number_t(MemoryLayout<task_thread_times_info_data_t>.stride / MemoryLayout<natural_t>.stride)
    let taskResult = withUnsafeMutablePointer(to: &taskInfo) { pointer -> kern_return_t in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(taskCount)) { rebound in
        task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), rebound, &taskCount)
      }
    }
    var ajugaFraction: Double?
    if taskResult == KERN_SUCCESS {
      let seconds = Double(taskInfo.user_time.seconds) + Double(taskInfo.user_time.microseconds) / 1_000_000
        + Double(taskInfo.system_time.seconds) + Double(taskInfo.system_time.microseconds) / 1_000_000
      let now = Date()
      if let previousSeconds = lastTaskCpuSeconds, let previousAt = lastTaskAt {
        let elapsed = now.timeIntervalSince(previousAt)
        if elapsed > 0.4 {
          ajugaFraction = max(0, (seconds - previousSeconds) / elapsed)
        }
      }
      lastTaskCpuSeconds = seconds
      lastTaskAt = now
    }
    return (systemFraction, ajugaFraction)
  }

  /// Apple's battery registry reports temperature in centi-celsius when the sandbox allows the read.
  func batteryCelsius() -> Double? {
    if iokitHandle == nil {
      iokitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
    }
    guard let handle = iokitHandle,
          let matchingSym = dlsym(handle, "IOServiceMatching"),
          let getSym = dlsym(handle, "IOServiceGetMatchingService"),
          let propSym = dlsym(handle, "IORegistryEntryCreateCFProperty"),
          let releaseSym = dlsym(handle, "IOObjectRelease")
    else { return nil }

    typealias ServiceMatching = @convention(c) (UnsafePointer<CChar>) -> CFMutableDictionary?
    typealias GetMatching = @convention(c) (UInt32, CFDictionary) -> UInt32
    typealias CreateProp = @convention(c) (UInt32, CFString, CFAllocator?, UInt32) -> Unmanaged<CFTypeRef>?
    typealias ObjectRelease = @convention(c) (UInt32) -> Int32

    let matching = unsafeBitCast(matchingSym, to: ServiceMatching.self)
    let getService = unsafeBitCast(getSym, to: GetMatching.self)
    let createProp = unsafeBitCast(propSym, to: CreateProp.self)
    let release = unsafeBitCast(releaseSym, to: ObjectRelease.self)

    let services = ["AppleSmartBattery", "AppleARMPMUCharger", "AppleD1972PMU"]
    let keys = ["Temperature", "VirtualTemperature", "BatteryTemperature"]
    for serviceName in services {
      guard let dictionary = matching(serviceName) else { continue }
      let service = getService(0, dictionary)
      if service == 0 { continue }
      defer { _ = release(service) }
      for key in keys {
        guard let property = createProp(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
              let number = property as? NSNumber
        else { continue }
        if let celsius = Self.celsius(fromRaw: number.doubleValue) {
          return celsius
        }
      }
    }
    return nil
  }

  static func celsius(fromRaw raw: Double) -> Double? {
    let celsius = raw > 150 && raw < 8000 ? raw / 100.0 : raw
    guard celsius >= 5, celsius <= 70 else { return nil }
    return (celsius * 10).rounded() / 10
  }

  static func batteryName(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .charging: return "charging"
    case .full: return "full"
    case .unplugged: return "unplugged"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }

  func emit() {
    sink?(payload())
  }

  static func name(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
