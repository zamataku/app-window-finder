import SwiftUI
import AppKit

/// Hotkey settings screen
public struct HotkeySettingsView: View {
    @State private var currentSettings: HotkeySettings
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt16?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @Environment(\.dismiss) private var dismiss
    
    private let onSettingsChanged: (HotkeySettings) -> Void
    
    public init(currentSettings: HotkeySettings, onSettingsChanged: @escaping (HotkeySettings) -> Void) {
        self._currentSettings = State(initialValue: currentSettings)
        self.onSettingsChanged = onSettingsChanged
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Hotkey Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Hotkey")
                    .font(.headline)
                
                HStack {
                    Text("Press:")
                        .foregroundColor(.secondary)
                    
                    Text(currentSettings.displayString)
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Record New Hotkey")
                    .font(.headline)
                
                Button(action: startRecording) {
                    HStack {
                        if isRecording {
                            Text("Recording... Press your desired hotkey")
                                .foregroundColor(.orange)
                        } else if let keyCode = recordedKeyCode {
                            let newSettings = HotkeySettings(keyCode: keyCode, modifierFlags: recordedModifiers)
                            Text("Recorded: \(newSettings.displayString)")
                                .foregroundColor(.green)
                        } else {
                            Text("Click to record new hotkey")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                Button("Reset to Default") {
                    recordedKeyCode = nil
                    recordedModifiers = []
                    currentSettings = .default
                }
                .foregroundColor(.orange)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Apply") {
                    applySettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedKeyCode == nil && currentSettings == HotkeySettings.load())
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
    
    private func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = []
        
        var eventMonitor: Any?
        
        // Start monitoring key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                recordedKeyCode = event.keyCode
                recordedModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
                isRecording = false
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                }
                return nil
            }
            return event
        }
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if isRecording {
                isRecording = false
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        }
    }
    
    private func applySettings() {
        let finalSettings: HotkeySettings
        
        if let keyCode = recordedKeyCode {
            finalSettings = HotkeySettings(keyCode: keyCode, modifierFlags: recordedModifiers)
        } else {
            finalSettings = currentSettings
        }
        
        onSettingsChanged(finalSettings)
        dismiss()
    }
}

// Preview removed to fix build issues with macro system