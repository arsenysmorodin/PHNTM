import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {

    let camera: CameraManager
    let directionGesture: DirectionGestureEngine
    let browserTabs: BrowserTabController
    let appStatus: AppStatusStore

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
        browserTabs = BrowserTabController()
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
        camera.start()
    }

    func stopCamera() {
        guard isTracking else { return }

        camera.stop()
        directionGesture.reset()
        appStatus.updateGuardPalm(false)
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

    private func syncPermissionStatus() {
        appStatus.updatePermissions(
            camera: camera.hasCameraPermission,
            inputControl: browserTabs.hasInputControlPermission,
            browserControlEnabled: browserControlEnabled
        )
    }
}
