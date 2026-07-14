import Testing
@testable import LivelyCore

@Suite("Battery pause policy")
struct BatteryPolicyTests {

    @Test func acPowerNeverPauses() {
        let d = WallpaperController.batteryPauseDecision(
            isOnBattery: false,
            level: 10,
            pauseEnabled: true,
            threshold: 50
        )
        #expect(d.shouldPause == false)
        #expect(d.isForcedFloor == false)
    }

    @Test func forcedFloorAtOrBelow25() {
        let d = WallpaperController.batteryPauseDecision(
            isOnBattery: true,
            level: 25,
            pauseEnabled: false,
            threshold: 50
        )
        #expect(d.shouldPause == true)
        #expect(d.isForcedFloor == true)

        let below = WallpaperController.batteryPauseDecision(
            isOnBattery: true,
            level: 12,
            pauseEnabled: false,
            threshold: 50
        )
        #expect(below.shouldPause == true)
        #expect(below.isForcedFloor == true)
    }

    @Test func userThresholdWhenEnabled() {
        let d = WallpaperController.batteryPauseDecision(
            isOnBattery: true,
            level: 40,
            pauseEnabled: true,
            threshold: 45
        )
        #expect(d.shouldPause == true)
        #expect(d.isForcedFloor == false)

        let above = WallpaperController.batteryPauseDecision(
            isOnBattery: true,
            level: 50,
            pauseEnabled: true,
            threshold: 45
        )
        #expect(above.shouldPause == false)
    }

    @Test func userThresholdIgnoredWhenDisabledAboveFloor() {
        let d = WallpaperController.batteryPauseDecision(
            isOnBattery: true,
            level: 40,
            pauseEnabled: false,
            threshold: 45
        )
        #expect(d.shouldPause == false)
        #expect(d.isForcedFloor == false)
    }

    @Test func clampThresholdRespectsFloor() {
        #expect(AppPreferences.clampThreshold(10) == 25)
        #expect(AppPreferences.clampThreshold(35) == 35)
        #expect(AppPreferences.clampThreshold(120) == 100)
    }
}
