import SwiftUI
import DoomCore

@MainActor
public struct MainWindowView: View {
    @Bindable public var model: MainWindowModel
    @State private var isReplacingKey: Bool = false
    @State private var replacementKeyInput: String = ""

    public init(model: MainWindowModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            DoomTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DoomTheme.Spacing.l) {
                    // 1. Header
                    headerSection

                    // 2. Setup checklist
                    setupChecklistSection

                    // 3. Gemini Settings
                    geminiSection

                    // 4. Shortcuts
                    shortcutsSection

                    // 5. Privacy
                    privacySection

                    // 6. About
                    aboutSection
                }
                .padding(DoomTheme.Spacing.l)
            }
        }
        .frame(minWidth: 560, maxWidth: 560, minHeight: 480)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.isPrivacySheetPresented) {
            PrivacyNoticeView(
                onUnderstand: {
                    model.acknowledgePrivacyNotice()
                },
                onDismiss: {
                    model.isPrivacySheetPresented = false
                }
            )
        }
        .confirmationDialog(
            "Remove the API key from this Mac?",
            isPresented: $model.isRemoveKeyAlertPresented,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    await model.removeAPIKey()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await model.refresh()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.xs) {
            Text(model.title)
                .font(.system(size: 28, weight: .heavy, design: .default))
                .tracking(6.0)
                .foregroundStyle(DoomTheme.metal)

            HStack(spacing: DoomTheme.Spacing.xs) {
                Text(model.versionText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DoomTheme.textSecondary)

                Text("·")
                    .foregroundStyle(DoomTheme.steel)

                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(statusTextColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall status: \(model.statusText)")
    }

    private var statusColor: Color {
        switch model.status {
        case .ready: return DoomTheme.accent
        case .setupNeeded: return DoomTheme.warning
        case .degraded: return DoomTheme.warning
        }
    }

    private var statusTextColor: Color {
        switch model.status {
        case .ready: return DoomTheme.accentText
        case .setupNeeded: return DoomTheme.warning
        case .degraded: return DoomTheme.warning
        }
    }

    // MARK: - Setup Checklist

    private var setupChecklistSection: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("Setup Checklist")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                if model.isSetupComplete {
                    HStack(spacing: DoomTheme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DoomTheme.accentText)
                        Text("Setup complete")
                            .font(.body)
                            .foregroundStyle(DoomTheme.accentText)
                    }
                    .padding(.vertical, DoomTheme.Spacing.xxs)
                } else {
                    VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
                        // Accessibility row
                        checklistRow(
                            icon: "hand.raised.fill",
                            title: "Accessibility",
                            statusWord: model.isAccessibilityGranted ? "Granted" : "Not granted",
                            isOk: model.isAccessibilityGranted
                        ) {
                            if !model.isAccessibilityGranted {
                                HStack(spacing: DoomTheme.Spacing.xs) {
                                    Button("Grant Access…") {
                                        model.requestAccessibility()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(DoomTheme.accent)

                                    Button("Open System Settings") {
                                        model.openAccessibilitySettings()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        Divider().background(DoomTheme.steel.opacity(0.4))

                        // Gemini API key row
                        checklistRow(
                            icon: "key.fill",
                            title: "Gemini API key",
                            statusWord: model.hasAPIKey ? "Saved in Keychain" : "Not set",
                            isOk: model.hasAPIKey
                        )

                        Divider().background(DoomTheme.steel.opacity(0.4))

                        // Privacy notice row
                        checklistRow(
                            icon: "doc.text.fill",
                            title: "Privacy notice",
                            statusWord: model.isPrivacyReviewed ? "Reviewed" : "Not reviewed",
                            isOk: model.isPrivacyReviewed
                        ) {
                            if !model.isPrivacyReviewed {
                                Button("Review…") {
                                    model.isPrivacySheetPresented = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(DoomTheme.accent)
                            }
                        }
                    }
                }
            }
        }
    }

    private func checklistRow<Actions: View>(
        icon: String,
        title: String,
        statusWord: String,
        isOk: Bool,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        HStack(alignment: .center) {
            Image(systemName: icon)
                .foregroundStyle(isOk ? DoomTheme.accentText : DoomTheme.warning)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(DoomTheme.textPrimary)

                Text(statusWord)
                    .font(.caption)
                    .foregroundStyle(isOk ? DoomTheme.accentText : DoomTheme.warning)
            }

            Spacer()

            actions()
        }
    }

    // MARK: - Gemini Section

    private var geminiSection: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("Gemini")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                // API Key controls
                VStack(alignment: .leading, spacing: DoomTheme.Spacing.xs) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundStyle(DoomTheme.textSecondary)

                    if model.hasAPIKey && !isReplacingKey {
                        HStack {
                            Text("Saved in Keychain")
                                .font(.body)
                                .foregroundStyle(DoomTheme.accentText)

                            Spacer()

                            Button(model.isTestingConnection ? "Testing…" : "Test Connection") {
                                Task {
                                    await model.testConnection()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isTestingConnection)

                            Button("Replace…") {
                                isReplacingKey = true
                            }
                            .buttonStyle(.bordered)

                            Button("Remove") {
                                model.isRemoveKeyAlertPresented = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if model.isTestingConnection {
                            HStack(spacing: DoomTheme.Spacing.xs) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Verifying connection to Gemini (sends a minimal 1-token test prompt; uses 1 request)…")
                                    .font(.caption)
                                    .foregroundStyle(DoomTheme.textSecondary)
                            }
                        } else if let result = model.testConnectionResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(model.isTestConnectionSuccess ? DoomTheme.accentText : DoomTheme.error)
                        }
                    } else {
                        HStack {
                            SecureField(
                                "Paste your Gemini API key",
                                text: isReplacingKey ? $replacementKeyInput : $model.apiKeyInput
                            )
                            .textFieldStyle(.roundedBorder)

                            Button("Save") {
                                let key = isReplacingKey ? replacementKeyInput : model.apiKeyInput
                                Task {
                                    await model.saveAPIKey(key)
                                    isReplacingKey = false
                                    replacementKeyInput = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DoomTheme.accent)
                            .disabled(model.isSavingKey)

                            if isReplacingKey {
                                Button("Cancel") {
                                    isReplacingKey = false
                                    replacementKeyInput = ""
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if let error = model.apiKeyStatusMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(DoomTheme.error)
                        }
                    }

                    Text("Get a key from Google AI Studio. DOOM stores it only in your Mac's Keychain.")
                        .font(.footnote)
                        .foregroundStyle(DoomTheme.textTertiary)
                }

                Divider().background(DoomTheme.steel.opacity(0.4))

                // Model ID controls
                VStack(alignment: .leading, spacing: DoomTheme.Spacing.xs) {
                    Text("Model")
                        .font(.subheadline)
                        .foregroundStyle(DoomTheme.textSecondary)

                    HStack {
                        TextField("Model ID", text: $model.modelInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.setModel(model.modelInput)
                            }

                        if model.modelInput != ModelID.default.rawValue {
                            Button("Reset") {
                                model.resetModel()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let err = model.modelError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(DoomTheme.error)
                    }

                    Text("Changing the model can change quality, speed and cost.")
                        .font(.footnote)
                        .foregroundStyle(DoomTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("Shortcuts")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                HStack {
                    Text("Activation")
                        .font(.body)
                        .foregroundStyle(DoomTheme.textPrimary)

                    Spacer()

                    Text("Fn ⌃ ⌥")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(model.isAccessibilityGranted ? DoomTheme.accentText : DoomTheme.warning)
                }

                HStack {
                    Text("Show / Hide Panel")
                        .font(.body)
                        .foregroundStyle(DoomTheme.textPrimary)

                    Spacer()

                    Text("⌃⇧H")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(DoomTheme.accentText)
                }

                Text("Control-Shift-H is reserved globally to show or hide the DOOM panel.")
                    .font(.footnote)
                    .foregroundStyle(DoomTheme.textTertiary)
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("Privacy")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                HStack {
                    Text("DOOM sends only your selected text to Gemini when activated.")
                        .font(.body)
                        .foregroundStyle(DoomTheme.textSecondary)

                    Spacer()

                    Button("View Privacy Notice") {
                        model.isPrivacySheetPresented = true
                    }
                    .buttonStyle(.bordered)
                }

                Divider().background(DoomTheme.steel.opacity(0.4))

                Toggle(isOn: Binding(
                    get: { model.copyFallbackEnabled },
                    set: { model.setCopyFallback($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Copy Fallback")
                            .font(.body)
                            .foregroundStyle(DoomTheme.textPrimary)

                        Text("When an app doesn't share its selection with DOOM, DOOM can press ⌘C for you, read the copied text, and put your previous clipboard back. Clipboard managers and Universal Clipboard may still see the copied text. If DOOM quits unexpectedly during the copy, your previous clipboard contents can be lost. Protected clipboard content (for example from password managers) is never touched.")
                            .font(.footnote)
                            .foregroundStyle(DoomTheme.textTertiary)
                            .lineSpacing(2)
                    }
                }
                .toggleStyle(.switch)

                Divider().background(DoomTheme.steel.opacity(0.4))

                Toggle(isOn: Binding(
                    get: { model.privacyState.requested },
                    set: { model.setPrivacyMode($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Mode")
                            .font(.body)
                            .foregroundStyle(DoomTheme.textPrimary)

                        Text("Excludes DOOM's response overlay from window and display capture where supported by macOS. The overlay remains visible and usable locally.")
                            .font(.footnote)
                            .foregroundStyle(DoomTheme.textTertiary)
                            .lineSpacing(2)
                    }
                }
                .toggleStyle(.switch)

                if model.privacyState.requested {
                    privacyDetailsView
                }
            }
        }
    }

    @ViewBuilder
    private var privacyDetailsView: some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
            Text("Sharing Method")
                .font(.subheadline.bold())
                .foregroundStyle(DoomTheme.textSecondary)

            Picker("How are you sharing?", selection: Binding(
                get: { model.privacyState.sharingContext },
                set: { model.setSharingContext($0) }
            )) {
                ForEach(SharingContext.allCases) { context in
                    Text(context.rawValue).tag(context)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .top, spacing: DoomTheme.Spacing.s) {
                Image(systemName: model.privacyState.isVerifiedProtected ? "checkmark.shield.fill" : "info.circle.fill")
                    .foregroundStyle(model.privacyState.isVerifiedProtected ? DoomTheme.accent : DoomTheme.warning)
                    .font(.body)

                Text(model.privacyState.statusDescription)
                    .font(.footnote)
                    .foregroundStyle(DoomTheme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(DoomTheme.Spacing.s)
            .background(DoomTheme.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))

            HStack {
                Button(action: {
                    Task {
                        await model.runSelfTest()
                    }
                }) {
                    if model.isSelfTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test Local Exclusion")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isSelfTesting)

                Text("Verifies overlay window exclusion property. Does not verify third-party WebRTC capture paths.")
                    .font(.caption)
                    .foregroundStyle(DoomTheme.textTertiary)
            }

            Toggle(isOn: Binding(
                get: { model.privacyState.hideLocallyFallbackEnabled },
                set: { model.setHideLocallyFallback($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hide overlay locally while sharing")
                        .font(.subheadline)
                        .foregroundStyle(DoomTheme.textPrimary)

                    Text("Explicit opt-in. Keeps the overlay hidden off-screen during active sharing and suppresses auto-showing upon query completion. Responses are preserved in memory. Press ⌃⇧H to deliberately reveal the response when safe.")
                        .font(.caption)
                        .foregroundStyle(DoomTheme.textTertiary)
                }
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended Alternatives:")
                    .font(.caption.bold())
                    .foregroundStyle(DoomTheme.textSecondary)

                Text("• Share a single window: Share only the target application window in Google Meet instead of the entire screen. macOS isolates the shared window at the compositor level, keeping DOOM excluded.")
                    .font(.caption)
                    .foregroundStyle(DoomTheme.textTertiary)

                Text("• Separate display: Move DOOM to an external or secondary display that is not being shared.")
                    .font(.caption)
                    .foregroundStyle(DoomTheme.textTertiary)
            }
            .padding(.top, 2)
        }
        .padding(.top, DoomTheme.Spacing.xs)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("About")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                Text(model.phaseNote)
                    .font(.footnote)
                    .foregroundStyle(DoomTheme.textTertiary)
                    .lineSpacing(2)

                HStack {
                    Spacer()
                    Button("Quit DOOM") {
                        #if canImport(AppKit)
                        NSApp.terminate(nil)
                        #endif
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Container Helper

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(DoomTheme.Spacing.m)
        .background(DoomTheme.bgHigh.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DoomTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DoomTheme.cardRadius)
                .stroke(DoomTheme.steel.opacity(0.4), lineWidth: 1)
        )
    }
}
