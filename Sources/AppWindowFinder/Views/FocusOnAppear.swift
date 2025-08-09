import SwiftUI
import AppKit

struct FocusOnAppear: ViewModifier {
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onAppear {
                // Immediate focus attempt
                isFocused = true
                
                // Delayed focus attempt as backup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if !isFocused {
                        isFocused = true
                    }
                }
            }
    }
}

extension View {
    func focusOnAppear() -> some View {
        modifier(FocusOnAppear())
    }
}