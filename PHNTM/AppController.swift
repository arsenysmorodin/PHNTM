import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {

    let camera: CameraManager
    let directionGesture: DirectionGestureEngine
    let brightnessGesture: BrightnessGestureEngine
    let browserTabs: BrowserTabController
    let appStatus: AppStatusStore

    private let displayBrightness: DisplayBrightnessController

    @Published private(set) var isTracking = false
    @Published var browserControlEnabled: Bool {
        didSet {
            guard browserControlEnabled != oldValue else { return }

            UserDefaults.standard.set(
                browserControlEnabled,
                forKey: AppStorageKeys.browserControlEnabled
            )
            browserTabs.setEnabled(browserControlEnabled)
            syncPermissionStatus()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init(appStatus: AppStatusStore) {
        self.appStatus = appStatus
        camera = CameraManager()
        directionGesture = DirectionGestureEngine()
        brightnessGesture = BrightnessGestureEngine()
        browserTabs = BrowserTabController()
        displayBrightness = DisplayBrightnessController()
        browserControlEnabled = UserDefaults.standard.bool(
            forKey: AppStorageKeys.browserControlEnabled
        )

        bindRuntimeState()
        browserTabs.setEnabled(browserControlEnabled)
        syncPermissionStatus()
    }

    func toggleCamera() {
        isTracking ? stopCamera() : startCamera()
    }

    func startCamera() {
        guard !isTracking else { return }

        isTracking = true
        directionGesture.reset()
        brightnessGesture.reset()
        camera.start()
    }

    func stopCamera() {
        guard isTracking else { return }

        camera.stop()
        directionGesture.reset()
        brightnessGesture.reset()
        appStatus.updateGuardPalm(false)
        appStatus.updateBrightnessGestureArmed(false)
        isTracking = false
    }

    func completeOnboarding() {
        browserControlEnabled = true
        browserTabs.setEnabled(true)
        syncPermissionStatus()
        startCamera()
    }

    func refreshPermissions() {
        camera.refreshAuthorizationStatus()
        browserTabs.refreshPermissionStatus()
        syncPermissionStatus()
    }

    private func bindRuntimeState() {
        camera.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        directionGesture.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        brightnessGesture.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        browserTabs.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        camera.$hands
            .sink { [weak self] hands in
                self?.process(hands: hands)
            }
            .store(in: &cancellables)

        camera.$authorizationStatus
            .sink { [weak self] _ in
                self?.syncPermissionStatus()
            }
            .store(in: &cancellables)

        camera.$errorMessage
            .sink { [weak self] message in
                guard let self else { return }

                if let message {
                    appStatus.reportError(message)
                } else {
                    appStatus.clearPersistentError()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )
        .sink { [weak self] _ in
            self?.refreshPermissions()
        }
        .store(in: &cancellables)
    }

    private func process(hands: [[CGPoint?]]) {
        guard isTracking else { return }

        let brightnessEvent = brightnessGesture.process(hands: hands)
        let brightnessIsArmed = switch brightnessGesture.phase {
        case .readyToClose, .closing:
            true
        case .idle, .arming, .waitingForRelease:
            false
        }
        appStatus.updateBrightnessGestureArmed(brightnessIsArmed)

        if brightnessEvent == .dimDisplay {
            directionGesture.reset()
            performBrightnessAction()
            return
        }

        // While the two-palms sequence is in progress, it owns both hands.
        // This prevents intermediate closing frames from becoming Safari
        // commands and guarantees one action per completed closure.
        if brightnessGesture.phase.isEngaged {
            directionGesture.reset()
            appStatus.updateGuardPalm(false)
            return
        }

        let isGuardPresent = hands.contains(
            where: GestureClassifier.isOpenPalm
        )
        appStatus.updateGuardPalm(isGuardPresent)

        let pointingHand = hands.first(
            where: GestureClassifier.isPointing
        ) ?? []

        guard let event = directionGesture.process(
            landmarks: pointingHand,
            isGuardPresent: isGuardPresent
        ) else {
            return
        }

        print("PHNTM: \(event.rawValue)")
        appStatus.reportGesture(event)

        guard browserControlEnabled else { return }

        let didPerform = browserTabs.perform(event)
        syncPermissionStatus()

        if !didPerform, browserTabs.hasInputControlPermission {
            appStatus.reportTransientError(browserTabs.statusText)
        }
    }

    private func performBrightnessAction() {
        print("PHNTM: DIM DISPLAY")
        appStatus.reportBrightnessAdjusted()

        Task { [weak self] in
            guard let self else { return }

            do {
                try await displayBrightness.dimToNearMinimum()
            } catch is CancellationError {
                return
            } catch {
                appStatus.reportTransientError(error.localizedDescription)
                syncPermissionStatus()
            }
        }
    }

    private func syncPermissionStatus() {
        appStatus.updatePermissions(
            camera: camera.hasCameraPermission,
            inputControl: browserTabs.hasInputControlPermission,
            browserControlEnabled: browserControlEnabled
        )
    }
}
