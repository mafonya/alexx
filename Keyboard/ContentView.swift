import SwiftUI
import UIKit
import Observation

private let appGroupIdentifier = "group.com.michaelabramovpersonalteam.Keyboard"
private let libraryFilename = "snippets.json"
private let categoriesFilename = "categories.json"

struct Snippet: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var collection: String
    var icon: String?
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        collection: String,
        icon: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.collection = collection
        self.icon = icon
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}

private enum SnippetLibrary {
    static let starterSnippets = [
        Snippet(title: "Quick reply", content: "Thanks! I’ll get back to you shortly.", collection: "Replies", icon: "💬", isFavorite: true),
        Snippet(title: "Email", content: "hello@example.com", collection: "Personal", icon: "✉️", isFavorite: true),
        Snippet(title: "Meeting", content: "Would you be available for a quick call this week?", collection: "Work", icon: "📅")
    ]

    static func load() -> [Snippet] {
        guard let data = try? Data(contentsOf: fileURL),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return starterSnippets
        }
        return snippets
    }

    static func save(_ snippets: [Snippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func loadCategories() -> [String] {
        guard let data = try? Data(contentsOf: categoriesURL),
              let categories = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return categories
    }

    static func saveCategories(_ categories: [String]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        try? data.write(to: categoriesURL, options: .atomic)
    }

    private static var fileURL: URL {
        containerURL.appendingPathComponent(libraryFilename)
    }

    private static var categoriesURL: URL {
        containerURL.appendingPathComponent(categoriesFilename)
    }

    private static var containerURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        try? FileManager.default.createDirectory(
            at: container,
            withIntermediateDirectories: true
        )
        return container
    }
}

@MainActor
@Observable
final class SnippetStore {
    var snippets: [Snippet] {
        didSet { SnippetLibrary.save(snippets) }
    }

    private var savedCategories: [String] {
        didSet { SnippetLibrary.saveCategories(savedCategories) }
    }

    init() {
        let loadedSnippets = SnippetLibrary.load()
        snippets = loadedSnippets
        SnippetLibrary.save(loadedSnippets)

        let snippetCategories = Set(loadedSnippets.map(\.collection))
        let storedCategories = Set(SnippetLibrary.loadCategories())
        savedCategories = Array(snippetCategories.union(storedCategories)).sorted()
        SnippetLibrary.saveCategories(savedCategories)
    }

    var collections: [String] {
        savedCategories
    }

    func add(_ snippet: Snippet) {
        addCategory(snippet.collection)
        snippets.insert(snippet, at: 0)
    }

    func update(_ snippet: Snippet) {
        addCategory(snippet.collection)
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
    }

    func delete(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
    }

    func toggleFavorite(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index].isFavorite.toggle()
    }

    func addCategory(_ name: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty,
              !savedCategories.contains(where: {
                  $0.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
              }) else {
            return
        }

        savedCategories.append(normalizedName)
        savedCategories.sort()
    }

    func renameCategory(_ category: String, to newName: String) {
        let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, normalizedName != category else { return }

        for index in snippets.indices where snippets[index].collection == category {
            snippets[index].collection = normalizedName
        }

        savedCategories.removeAll { $0 == category }
        addCategory(normalizedName)
    }

    func deleteCategory(_ category: String) {
        savedCategories.removeAll { $0 == category }
        snippets.removeAll { $0.collection == category }
    }
}

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var store = SnippetStore()
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedCollection: String?
    @State private var editorItem: EditorItem?
    @State private var isManagingCategories = false

    private var filteredSnippets: [Snippet] {
        store.snippets.filter { snippet in
            let matchesCollection = selectedCollection == nil || snippet.collection == selectedCollection
            let matchesSearch = searchText.isEmpty ||
                snippet.title.localizedStandardContains(searchText) ||
                snippet.content.localizedStandardContains(searchText)
            return matchesCollection && matchesSearch
        }
    }

    var body: some View {
        Group {
            if hasSeenWelcome {
                mainTabs
            } else {
                WelcomeView(
                    createSnippet: {
                        selectedTab = 0
                        hasSeenWelcome = true
                        editorItem = EditorItem()
                    },
                    setUpKeyboard: {
                        selectedTab = 1
                        hasSeenWelcome = true
                    }
                )
            }
        }
        .tint(.accentColor)
        .sheet(item: $editorItem) { item in
            SnippetEditor(
                snippet: item.snippet,
                existingCollections: store.collections
            ) { snippet in
                if item.snippet == nil {
                    store.add(snippet)
                } else {
                    store.update(snippet)
                }
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VStack(spacing: 0) {
                    SnippetSearchField(text: $searchText)
                    CollectionFilter(
                        collections: store.collections,
                        selection: $selectedCollection
                    )
                    snippetList
                }
                .navigationTitle("Snippets")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Manage Categories", systemImage: "folder") {
                            isManagingCategories = true
                        }

                        Button("New snippet", systemImage: "plus") {
                            editorItem = EditorItem()
                        }
                    }
                }
                .sheet(isPresented: $isManagingCategories) {
                    CategoryManager(store: store)
                }
                .onChange(of: store.collections) { _, collections in
                    if let selectedCollection, !collections.contains(selectedCollection) {
                        self.selectedCollection = nil
                    }
                }
            }
            .tabItem {
                Label("Snippets", systemImage: "text.alignleft")
            }
            .tag(0)

            SetupView()
                .tabItem {
                    Label("Setup", systemImage: "keyboard")
                }
                .tag(1)
        }
    }

    private var snippetList: some View {
        List {
            if filteredSnippets.isEmpty {
                if store.snippets.isEmpty {
                    ContentUnavailableView(
                        "No snippets yet",
                        systemImage: "text.badge.plus",
                        description: Text("Tap the plus button to save text you use often.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(filteredSnippets) { snippet in
                    SnippetRow(snippet: snippet) {
                        store.toggleFavorite(snippet)
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        editorItem = EditorItem(snippet: snippet)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { filteredSnippets[$0].id }
                    store.snippets.removeAll { ids.contains($0.id) }
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct WelcomeView: View {
    let createSnippet: () -> Void
    let setUpKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 36)

            Image("SnippyMark")
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            Text("Snippy")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .padding(.top, 24)

            Text("Your words, one tap away.")
                .font(.title2.weight(.semibold))
                .padding(.top, 8)

            Text("Save the text you use often. Find it in your keyboard whenever you need it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                Label("Quick reply", systemImage: "text.alignleft")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Thanks! I’ll get back to you shortly.")
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 18))
            .padding(.top, 36)

            Spacer(minLength: 36)

            Button(action: createSnippet) {
                Text("Create a snippet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: setUpKeyboard) {
                Text("Set up keyboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 10)

            Text("Your snippets stay on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct SnippetSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search snippets", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct CategoryManager: View {
    @Environment(\.dismiss) private var dismiss
    let store: SnippetStore

    @State private var categoryBeingRenamed = ""
    @State private var renameDraft = ""
    @State private var categoryBeingDeleted = ""
    @State private var newCategoryDraft = ""
    @State private var isShowingRenameAlert = false
    @State private var isShowingAddAlert = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if store.collections.isEmpty {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "folder",
                        description: Text("Tap the plus button to create a category.")
                    )
                } else {
                    ForEach(store.collections, id: \.self) { category in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category)
                                    .font(.headline)
                                Text(
                                    "\(snippetCount(for: category)) " +
                                    (snippetCount(for: category) == 1 ? "snippet" : "snippets")
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Rename", systemImage: "pencil") {
                                categoryBeingRenamed = category
                                renameDraft = category
                                isShowingRenameAlert = true
                            }
                            .labelStyle(.iconOnly)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                categoryBeingDeleted = category
                                isShowingDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Category", systemImage: "plus") {
                        newCategoryDraft = ""
                        isShowingAddAlert = true
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("New Category", isPresented: $isShowingAddAlert) {
                TextField("Category name", text: $newCategoryDraft)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    store.addCategory(newCategoryDraft)
                }
                .disabled(newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("The new category will be available when creating or editing snippets.")
            }
            .alert("Rename Category", isPresented: $isShowingRenameAlert) {
                TextField("Category name", text: $renameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    store.renameCategory(categoryBeingRenamed, to: renameDraft)
                }
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("All snippets in this category will be updated.")
            }
            .confirmationDialog(
                "Delete \(categoryBeingDeleted)?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Category and Snippets", role: .destructive) {
                    store.deleteCategory(categoryBeingDeleted)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every snippet in the category.")
            }
        }
    }

    private func snippetCount(for category: String) -> Int {
        store.snippets.count { $0.collection == category }
    }
}

private struct CollectionFilter: View {
    let collections: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                FilterChip(title: "All", isSelected: selection == nil) {
                    selection = nil
                }

                ForEach(collections, id: \.self) { collection in
                    FilterChip(title: collection, isSelected: selection == collection) {
                        selection = collection
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isSelected ? .accentColor : .secondary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(snippet.icon ?? "💬")
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(snippet.title)
                        .font(.headline)
                    Text(snippet.collection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(snippet.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(
                snippet.isFavorite ? "Remove from favorites" : "Add to favorites",
                systemImage: snippet.isFavorite ? "star.fill" : "star",
                action: toggleFavorite
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(snippet.isFavorite ? .yellow : .secondary)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct EditorItem: Identifiable {
    let id = UUID()
    var snippet: Snippet?

    init(snippet: Snippet? = nil) {
        self.snippet = snippet
    }
}

private struct SnippetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let originalSnippet: Snippet?
    let existingCollections: [String]
    let save: (Snippet) -> Void

    @State private var title: String
    @State private var content: String
    @State private var collection: String
    @State private var newCollection: String
    @State private var icon: String
    @State private var isChoosingIcon = false
    @State private var isFavorite: Bool

    init(
        snippet: Snippet?,
        existingCollections: [String],
        save: @escaping (Snippet) -> Void
    ) {
        originalSnippet = snippet
        self.existingCollections = existingCollections
        self.save = save
        _title = State(initialValue: snippet?.title ?? "")
        _content = State(initialValue: snippet?.content ?? "")
        _collection = State(initialValue: snippet?.collection ?? existingCollections.first ?? "")
        _newCollection = State(initialValue: "")
        _icon = State(initialValue: snippet?.icon ?? "💬")
        _isFavorite = State(initialValue: snippet?.isFavorite ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Snippet") {
                    TextField("Title", text: $title)
                    TextField("Text to insert", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Icon") {
                    Button {
                        isChoosingIcon = true
                    } label: {
                        HStack {
                            Text("Icon")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(icon)
                                .font(.title)
                                .frame(width: 48, height: 48)
                                .background(.quaternary, in: .rect(cornerRadius: 10))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Icon, \(icon)")
                    .accessibilityHint("Choose a different emoji")
                }

                Section("Category") {
                    Picker("Category", selection: $collection) {
                        ForEach(existingCollections, id: \.self) { category in
                            Text(category).tag(category)
                        }
                        Text("Create New…").tag("")
                    }

                    if collection.isEmpty {
                        TextField("New category name", text: $newCollection)
                    }
                }

                Section {
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(originalSnippet == nil ? "New Snippet" : "Edit Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let snippet = Snippet(
                            id: originalSnippet?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            content: content,
                            collection: normalizedCategory,
                            icon: icon,
                            isFavorite: isFavorite,
                            createdAt: originalSnippet?.createdAt ?? .now
                        )
                        save(snippet)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isChoosingIcon) {
                EmojiIconChooser(icon: $icon)
                    .presentationDetents([.medium])
            }
        }
    }

    private var normalizedCategory: String {
        let selected = collection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty {
            return selected
        }

        let created = newCollection.trimmingCharacters(in: .whitespacesAndNewlines)
        return created.isEmpty ? "General" : created
    }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCategory = !collection.isEmpty ||
            !newCollection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && hasContent && hasCategory
    }
}

private struct EmojiIconChooser: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var icon: String

    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(icon)
                    .font(.system(size: 72))
                    .frame(width: 112, height: 112)
                    .background(.quaternary, in: .rect(cornerRadius: 24))

                TextField("Choose an emoji", text: $input)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onChange(of: input) { _, newValue in
                        guard let candidate = newValue.last, candidate.isEmoji else { return }
                        icon = String(candidate)
                        input = String(candidate)
                    }

                Text("Switch to the standard emoji keyboard and tap any emoji.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                input = icon
                isInputFocused = true
            }
        }
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains {
            $0.properties.isEmojiPresentation || $0.properties.isEmoji
        }
    }
}

private struct SetupView: View {
    @Environment(\.openURL) private var openURL
    @State private var tryText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Our Promise") {
                    Label("Free to use", systemImage: "gift")
                    Label("No data collection", systemImage: "hand.raised")
                }

                Section("Privacy") {
                    Label("Snippets stay on this device", systemImage: "iphone")
                    Label("No accounts or analytics", systemImage: "person.crop.circle.badge.xmark")
                    Label("No network access", systemImage: "wifi.slash")
                }

                Section {
                    SetupStep(number: 1, title: "Open Settings", detail: "Tap the button below. Then go to General, Keyboard, Keyboards.")
                    SetupStep(number: 2, title: "Add Snippy", detail: "Tap Add New Keyboard, then Snippy.")
                    SetupStep(number: 3, title: "Share your snippets", detail: "Tap Snippy in the keyboard list and turn on Allow Full Access. Built-in examples work without it. Snippy does not transmit what you type.")
                    SetupStep(number: 4, title: "Start typing", detail: "In a text field, tap the globe key and choose Snippy.")
                } header: {
                    Text("Four quick steps")
                }

                Section {
                    Button("Open Settings", systemImage: "gear") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }

                Section("Try it") {
                    TextField("Switch keyboards and insert a snippet", text: $tryText)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    if let supportURL = URL(string: "https://github.com/mafonya/snippy/issues") {
                        Link(destination: supportURL) {
                            LabeledContent("Support", value: "GitHub Issues")
                        }
                    }
                    if let repositoryURL = URL(string: "https://github.com/mafonya/snippy") {
                        Link(destination: repositoryURL) {
                            LabeledContent("GitHub repository", value: "mafonya/snippy")
                        }
                    }
                    NavigationLink("License") {
                        MITLicenseView()
                    }
                }
            }
            .navigationTitle("Keyboard Setup")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Snippy stores the snippets and categories you create on your device. The app and keyboard share them through an Apple App Group container.")
                Text("Snippy does not create accounts, use analytics or advertising, send snippets or typing activity to a server, or share your data with third parties.")
                Text("Full Access lets the keyboard read your personal snippets from the shared container. Without it, the keyboard offers built-in examples. The keyboard does not transmit what you type.")
                Text("You can delete snippets and categories in the app. Removing the app removes its locally stored data, subject to any device backups you control.")
                Text("For privacy questions, open an issue at https://github.com/mafonya/snippy/issues.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MITLicenseView: View {
    private static let licenseText = """
    Copyright (c) 2026 SnippetKeyboard contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """

    var body: some View {
        ScrollView {
            Text(Self.licenseText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("MIT License")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number, format: .number)
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(Color.accentColor, in: .circle)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
