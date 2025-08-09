import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var allItems: [SearchItem] = []
    @State private var filteredItems: [SearchItem] = []
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFieldFocused: Bool
    
    let onDismiss: () -> Void
    let onSelect: (SearchItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 20)
        .onAppear {
            // Clear search text and reset selection when window appears
            searchText = ""
            selectedIndex = 0
            loadItems()
            // Ensure focus on search field
            isSearchFieldFocused = true
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(NSLocalizedString("Search apps, windows, and tabs...", comment: "Search field placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($isSearchFieldFocused)
                .focusOnAppear()
                .onSubmit {
                    selectCurrentItem()
                }
                .onChange(of: searchText) { newValue in
                    filterItems(newValue)
                }
        }
        .padding()
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(filteredItems.indices, id: \.self) { index in
                SearchItemRow(
                    item: filteredItems[index],
                    isSelected: index == selectedIndex
                )
                .id(index)
                .onTapGesture {
                    selectedIndex = index
                    selectCurrentItem()
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .onChange(of: selectedIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .onAppear {
            // Prevent duplicate monitors
            if eventMonitor == nil {
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleKeyEvent(event)
                }
            }
        }
        .onDisappear {
            cleanupEventMonitor()
        }
    }
    
    private func loadItems() {
        allItems = WindowManager.shared.getAllSearchItems()
        // Show all items when search is empty
        filteredItems = searchText.isEmpty ? allItems : FuzzySearch.search(searchText, in: allItems)
    }
    
    private func filterItems(_ query: String) {
        filteredItems = FuzzySearch.search(query, in: allItems)
        selectedIndex = 0
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Check for Cmd+number shortcuts
        if event.modifierFlags.contains(.command) {
            if let characters = event.charactersIgnoringModifiers,
               let number = Int(characters),
               number >= 1 && number <= 9 {
                // Cmd+1 through Cmd+9 to select items
                let targetIndex = number - 1
                if targetIndex < filteredItems.count {
                    selectedIndex = targetIndex
                    selectCurrentItem()
                }
                return nil
            }
        }
        
        switch event.keyCode {
        case 126: // Up arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return nil
        case 125: // Down arrow
            if selectedIndex < filteredItems.count - 1 {
                selectedIndex += 1
            }
            return nil
        case 53: // Escape
            onDismiss()
            return nil
        case 36: // Enter
            selectCurrentItem()
            return nil
        case 48: // Tab
            if event.modifierFlags.contains(.shift) {
                // Shift+Tab - go up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
            } else {
                // Tab - go down
                if selectedIndex < filteredItems.count - 1 {
                    selectedIndex += 1
                }
            }
            return nil
        default:
            return event
        }
    }
    
    private func selectCurrentItem() {
        guard selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]
        
        // Record to usage history
        SearchHistoryManager.shared.recordItemUsage(item)
        
        // Also record search query to history (if not empty)
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            SearchHistoryManager.shared.recordSearchQuery(searchText)
        }
        
        onSelect(item)
        onDismiss()
    }
    
    private func cleanupEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct SearchItemRow: View {
    let item: SearchItem
    let isSelected: Bool
    
    var body: some View {
        HStack {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: iconName)
                    .foregroundColor(.accentColor)
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                    .font(.body)
                
                Text(item.subtitle)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private var accessibilityLabelText: String {
        let typeLabel: String
        switch item.type {
        case .app:
            typeLabel = NSLocalizedString("Application", comment: "Accessibility label for app type")
        case .window:
            typeLabel = NSLocalizedString("Window", comment: "Accessibility label for window type")
        case .tab:
            typeLabel = NSLocalizedString("Tab", comment: "Accessibility label for tab type")
        case .browserTab:
            typeLabel = NSLocalizedString("Browser Tab", comment: "Accessibility label for browser tab type")
        }
        
        return "\(typeLabel): \(item.title), \(item.subtitle)"
    }
    
    private var iconName: String {
        switch item.type {
        case .app:
            return "app.fill"
        case .window:
            return "macwindow"
        case .tab:
            return "safari"
        case .browserTab:
            return "globe"
        }
    }
}