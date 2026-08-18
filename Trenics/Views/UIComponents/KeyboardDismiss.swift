//
//  KeyboardDismiss.swift
//  Trenics
//

import SwiftUI
import UIKit

/// Closes the keyboard when the user taps anywhere outside a text field.
///
/// Done with a window-level tap recogniser rather than SwiftUI's
/// `.onTapGesture`, for two reasons:
///
/// * A tap gesture on a `Form` competes with the rows inside it. Because this
///   recogniser sets `cancelsTouchesInView = false`, touches still reach the
///   buttons and fields underneath and keep working normally.
/// * Its delegate ignores taps that land on a text field or text editor, so
///   moving from one field to another focuses the new field instead of
///   dismissing the keyboard the moment it opens.
private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var attachedWindow: UIWindow?
    private var recognizer: UITapGestureRecognizer?

    func attach() {
        guard recognizer == nil else { return }
        guard let window = Self.activeWindow() else { return }

        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)

        recognizer = tap
        attachedWindow = window
    }

    func detach() {
        if let recognizer, let attachedWindow {
            attachedWindow.removeGestureRecognizer(recognizer)
        }
        recognizer = nil
        attachedWindow = nil
    }

    private static func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }

    // MARK: UIGestureRecognizerDelegate

    /// Taps that land inside a text input are left alone — otherwise tapping a
    /// second field would dismiss the keyboard instead of moving focus.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    /// Never block whatever else is already handling the touch.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private struct DismissKeyboardOnTap: ViewModifier {
    @State private var coordinator = KeyboardDismissCoordinator()

    func body(content: Content) -> some View {
        content
            // Swiping the form down closes the keyboard too, which is what the
            // system keyboard behaviour leads people to expect.
            .scrollDismissesKeyboard(.interactively)
            .onAppear { coordinator.attach() }
            .onDisappear { coordinator.detach() }
    }
}

extension View {
    /// Tapping anywhere outside a text field closes the keyboard, for the
    /// lifetime of this view.
    func dismissesKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}
