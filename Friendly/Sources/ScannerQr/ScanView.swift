//
//  ScanView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI
import PhotosUI

struct ScanToUseAppView: View {
    @StateObject private var viewModel: ScanToUseAppViewModel
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    private var isBlocked: Bool

    @FocusState private var isLinkTextFieldFocused: Bool
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    init(
        isBlocked: Bool,
        onSuccess: @escaping () -> Void
    ) {
        self.isBlocked = isBlocked
        _viewModel = StateObject(wrappedValue: ScanToUseAppViewModel(onSuccess: onSuccess))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .idle: content
                case .loading: LoadingView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isBlocked {
                    toolbarContent
                }
            }
            .alert(
                viewModel.alert?.title ?? "",
                isPresented: Binding(
                    get: { viewModel.alert != nil },
                    set: { if !$0 { viewModel.alert = nil } },
                ),
                actions: {
                    Button(
                        LocalizedStringResource("scan_enter_error_alert_button_okay"),
                        role: .cancel,
                    ) { viewModel.resetState() }
                },
                message: {
                    if let message = viewModel.alert?.message {
                        Text(message)
                    }
                },
            )
            .sheet(isPresented: $viewModel.isScannerPresented) {
                QRScannerCameraView { code in
                    guard let code, !code.isEmpty else {
                        viewModel.closeScanner()
                        return
                    }
                    viewModel.handleScanned(code: code)
                }
            }
            .onChange(of: pickedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    defer { pickedPhotoItem = nil }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.handlePickedImageData(data)
                    } else {
                        viewModel.alert = .photoInvalidImage(
                            title: "scan_enter_error_alert_title_default",
                        )
                    }
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                qrCodeImage
                    .padding(.bottom, 8)

                infoTitle
                    .padding(.horizontal, 16)

                infoSubtitle
                    .padding(.horizontal, 16)

                Spacer(minLength: 40)

                inviteLinkTextField
                    .padding(.horizontal)

                openScannerButton
                    .padding(.horizontal)

                photosPicker
                    .padding(.horizontal)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .onTapGesture { isLinkTextFieldFocused = false }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(LocalizedStringResource("scanner_qrcode_navigation_title"))
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
        }
    }

    private var qrCodeImage: some View {
        Image(systemName: "qrcode.viewfinder")
            .font(.system(size: 56))
    }

    private var infoTitle: some View {
        Text(LocalizedStringResource("scan_enter_info_title"))
            .font(.title3)
            .multilineTextAlignment(.center)
    }

    private var infoSubtitle: some View {
        Text(LocalizedStringResource("scan_enter_info_subtitle"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var inviteLinkTextField: some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField(
                LocalizedStringResource("invite_link"),
                text: $viewModel.inviteLinkText,
            )
            .focused($isLinkTextFieldFocused)
            .font(.body)
            .frame(maxWidth: .infinity)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .autocapitalization(.none)
            .onSubmit { viewModel.handleEnteredInviteLinkText() }
            .overlay(alignment: .trailing) {
                if viewModel.inviteLinkText.isEmpty {
                    Button(LocalizedStringResource("paste")) {
                        guard let text = UIPasteboard.general.string else {
                            return
                        }
                        viewModel.inviteLinkText = text
                        viewModel.handleEnteredInviteLinkText()
                    }
                    .padding(.trailing, 8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
    }

    private var openScannerButton: some View {
        Button(
            action: { viewModel.openScanner() },
            label: {
                Text(LocalizedStringResource("scan_enter_open_scanner"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            },
        )
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.glassProminent)
    }

    private var photosPicker: some View {
        PhotosPicker(
            selection: $pickedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Text(LocalizedStringResource("scan_enter_open_photo_scanner"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.glass)
    }
}

private struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
