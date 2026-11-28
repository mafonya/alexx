import SwiftUI
import UIKit
import Observation
import CoreTransferable
import UniformTypeIdentifiers
import Security

private let appGroupIdentifier = "group.com.snippykeyboard.app"
private let libraryFilename = "snippets.json"
private let categoriesFilename = "categories.json"

struct Snippet: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var collection: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        collection: String,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.collection = collection
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}

private struct SnippetBackup: Codable, Sendable {
    let version: Int
    let snippets: [Snippet]
    let categories: [String]
    let backedUpAt: Date?

    init(
        version: Int = 1,
        snippets: [Snippet],
        categories: [String],
        backedUpAt: Date? = nil
    ) {
        self.version = version
        self.snippets = snippets
        self.categories = categories
        self.backedUpAt = backedUpAt
    }
}

private struct SnippetArchive: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { archive in
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("alexx-\(UUID().uuidString)")
                .appendingPathExtension("json")
            try archive.data.write(to: fileURL, options: .atomic)
            return SentTransferredFile(fileURL)
        }
        .suggestedFileName { _ in "alexx-backup.json" }
    }
}

private enum KeychainBackup {
    private static let service = "com.snippykeyboard.app.backup"
    private static let account = "snippet-library"

    static func save(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw BackupError(status: addStatus) }
        } else if updateStatus != errSecSuccess {
            throw BackupError(status: updateStatus)
        }
    }

    static func load() -> SnippetBackup? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SnippetBackup.self, from: data)
    }

    private struct BackupError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            String(localized: "The backup could not be saved (Keychain error \(status)).")
        }
    }
}

private enum SnippetLibrary {
    static let starterSnippets = [
        Snippet(title: "Quick reply", content: "Thanks! I’ll get back to you shortly.", collection: "Replies", isFavorite: true),
        Snippet(title: "Email", content: "hello@example.com", collection: "Personal", isFavorite: true),
        Snippet(title: "Meeting", content: "Would you be available for a quick call this week?", collection: "Work")
    ]

    static var hasStoredLibrary: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

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

    static func loadCategories() -> [String]? {
        guard let data = try? Data(contentsOf: categoriesURL),
              let categories = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
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

    private(set) var lastBackupDate: Date?

    init() {
        let keychainBackup = KeychainBackup.load()
        let loadedSnippets = SnippetLibrary.hasStoredLibrary
            ? SnippetLibrary.load()
            : keychainBackup?.snippets ?? SnippetLibrary.load()
        snippets = loadedSnippets
        SnippetLibrary.save(loadedSnippets)

        let snippetCategories = Set(loadedSnippets.map(\.collection).filter(Self.isNamedCategory))
        let restoredCategories = SnippetLibrary.loadCategories() ?? keychainBackup?.categories ?? []
        savedCategories = snippetCategories.union(restoredCategories.filter(Self.isNamedCategory)).sorted()
        lastBackupDate = keychainBackup?.backedUpAt
        SnippetLibrary.saveCategories(savedCategories)
    }

    var collections: [String] {
        savedCategories
    }

    fileprivate func makeArchive() -> SnippetArchive {
        SnippetArchive(data: (try? makeBackupData(backedUpAt: nil)) ?? Data("{}".utf8))
    }

    func saveBackup() throws {
        let backupDate = Date.now
        try KeychainBackup.save(makeBackupData(backedUpAt: backupDate))
        lastBackupDate = backupDate
    }

    func resetToSamples() {
        let samples = SnippetLibrary.starterSnippets
        snippets = samples
        savedCategories = Set(samples.map(\.collection)).sorted()
    }

    func restoreBackup() -> Bool {
        guard let backup = KeychainBackup.load(), backup.version == 1 else {
            return false
        }

        snippets = backup.snippets
        let categories = Set(backup.categories).union(backup.snippets.map(\.collection))
        savedCategories = categories.filter(Self.isNamedCategory).sorted()
        return true
    }

    private func makeBackupData(backedUpAt: Date?) throws -> Data {
        let backup = SnippetBackup(
            snippets: snippets,
            categories: savedCategories,
            backedUpAt: backedUpAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
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

    @discardableResult
    func importUncategorized(from text: String) -> Int {
        let imported = text.split(whereSeparator: \.isNewline).compactMap { line -> Snippet? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: ":") else { return nil }
            let title = trimmed[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let content = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !content.isEmpty else { return nil }
            return Snippet(title: String(title), content: String(content), collection: "")
        }
        guard !imported.isEmpty else { return 0 }
        snippets.insert(contentsOf: imported, at: 0)
        return imported.count
    }

    private static func isNamedCategory(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    @State private var snippetPendingDeletion: Snippet?

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
                    SnippetControls(
                        collections: store.collections,
                        selection: $selectedCollection,
                        searchText: $searchText
                    )
                    snippetList
                }
                .illustratedBackground()
                .navigationBarTitleDisplayMode(.inline)
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
                .confirmationDialog(
                    "Delete \(snippetPendingDeletion?.title ?? "this snippet")?",
                    isPresented: Binding(
                        get: { snippetPendingDeletion != nil },
                        set: { if !$0 { snippetPendingDeletion = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        guard let snippetPendingDeletion else { return }
                        store.snippets.removeAll { $0.id == snippetPendingDeletion.id }
                        self.snippetPendingDeletion = nil
                    }
                    Button("Cancel", role: .cancel) {
                        snippetPendingDeletion = nil
                    }
                } message: {
                    Text("This removes the snippet from this device.")
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

            SetupView(store: store)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            snippetPendingDeletion = snippet
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct WelcomeView: View {
    let createSnippet: () -> Void
    let setUpKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 36)

            Image("AlexxMark")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 16))
                .accessibilityHidden(true)

            Text("Alexx")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .illustratedBackground()
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
            .illustratedBackground()
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

private struct SnippetControls: View {
    let collections: [String]
    @Binding var selection: String?
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search snippets", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") {
                        searchText = ""
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selection == nil) {
                        selection = nil
                    }

                    ForEach(collections, id: \.self) { collection in
                        FilterChip(title: collection, isSelected: selection == collection) {
                            selection = collection
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(Color.accentColor)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule().stroke(.white.opacity(isSelected ? 0.18 : 0.35), lineWidth: 1)
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(snippet.title)
                        .font(.headline)
                    if !snippet.collection.isEmpty {
                        Text(snippet.collection)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
        .padding(16)
        .background(Color(uiColor: .systemBackground).opacity(0.8), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
        .listRowInsets(.init(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowBackground(Color.clear)
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
    @State private var isFavorite: Bool

    private static let noCategory = "\u{0}"

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
        _collection = State(initialValue: Self.initialCollection(for: snippet, existingCollections: existingCollections))
        _newCollection = State(initialValue: "")
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

                Section("Category") {
                    Picker("Category", selection: $collection) {
                        Text("No Category").tag(Self.noCategory)
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
            .illustratedBackground()
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
                            isFavorite: isFavorite,
                            createdAt: originalSnippet?.createdAt ?? .now
                        )
                        save(snippet)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var normalizedCategory: String {
        if collection == Self.noCategory {
            return ""
        }

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
        let hasCategory = collection == Self.noCategory || !collection.isEmpty ||
            !newCollection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && hasContent && hasCategory
    }

    private static func initialCollection(for snippet: Snippet?, existingCollections: [String]) -> String {
        guard let snippet else { return existingCollections.first ?? "" }
        return snippet.collection.isEmpty ? noCategory : snippet.collection
    }
}

private struct SetupView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(IllustratedBackground.clearPreferenceKey) private var clearsBackground = false
    let store: SnippetStore
    @State private var tryText = ""
    @State private var backupMessage: String?
    @State private var confirmsRestore = false
    @State private var showsResetSheet = false
    @State private var confirmsReset = false
    @FocusState private var isTryFieldFocused: Bool

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
                    SetupStep(number: 2, title: "Add Alexx", detail: "Tap Add New Keyboard, then Alexx.")
                    SetupStep(number: 3, title: "Share your snippets", detail: "Tap Alexx in the keyboard list and turn on Allow Full Access. Built-in examples work without it. Alexx does not transmit what you type.")
                    SetupStep(number: 4, title: "Start typing", detail: "In a text field, tap the globe key and choose Alexx.")
                } header: {
                    Text("Four quick steps")
                }

                Section {
                    Button("Open Settings", systemImage: "gear") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }

                Section {
                    NavigationLink {
                        ImportSnippetsView(store: store)
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }

                    ShareLink(
                        item: store.makeArchive(),
                        preview: SharePreview(
                            "Alexx backup",
                            image: Image(systemName: "doc.text")
                        )
                    ) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Button("Backup", systemImage: "key") {
                        do {
                            try store.saveBackup()
                            backupMessage = "Backup saved securely on this device."
                        } catch {
                            backupMessage = "Backup failed: \(error.localizedDescription)"
                        }
                    }

                    Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                        showsResetSheet = true
                    }

                    LabeledContent("Last backup") {
                        if let lastBackupDate = store.lastBackupDate {
                            Text(
                                lastBackupDate,
                                format: .dateTime
                                    .month(.abbreviated)
                                    .day()
                                    .year()
                                    .hour()
                                    .minute()
                            )
                        } else {
                            Text("Never")
                        }
                    }

                    if store.lastBackupDate != nil {
                        Button("Restore Backup", systemImage: "arrow.down.circle") {
                            confirmsRestore = true
                        }
                        .confirmationDialog("Restore your last backup?", isPresented: $confirmsRestore, titleVisibility: .visible) {
                            Button("Restore Backup", role: .destructive) {
                                backupMessage = store.restoreBackup()
                                    ? "Snippets and categories restored."
                                    : "The saved backup could not be read."
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This replaces your current snippets and categories. Changes made since the backup will be lost.")
                        }
                    }
                }

                Section("Try it") {
                    TextField("Switch keyboards and insert a snippet", text: $tryText)
                        .focused($isTryFieldFocused)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    if let supportURL = URL(string: "https://github.com/mafonya/alexx/issues") {
                        Link(destination: supportURL) {
                            LabeledContent("Support", value: "GitHub Issues")
                        }
                    }
                    if let repositoryURL = URL(string: "https://github.com/mafonya/alexx") {
                        Link(destination: repositoryURL) {
                            LabeledContent("GitHub repository", value: "mafonya/alexx")
                        }
                    }
                    NavigationLink("License") {
                        MITLicenseView()
                    }
                    Toggle("Clear Background", isOn: $clearsBackground)
                }
            }
            .illustratedBackground()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Keyboard Setup")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTryFieldFocused = false
                    }
                }
            }
            .alert("Backup", isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
            .sheet(isPresented: $showsResetSheet) {
                NavigationStack {
                    Form {
                        Text("Reset replaces your current snippets and categories with the default samples. Your saved backup is kept.")
                        Button("Continue", role: .destructive) {
                            confirmsReset = true
                        }
                    }
                    .illustratedBackground()
                    .navigationTitle("Reset snippets?")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showsResetSheet = false }
                        }
                    }
                    .alert("Restore default samples?", isPresented: $confirmsReset) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset Snippets", role: .destructive) {
                            store.resetToSamples()
                            showsResetSheet = false
                        }
                    } message: {
                        Text("This replaces all snippets and categories in your current library.")
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct ImportSnippetsView: View {
    @Environment(\.dismiss) private var dismiss
    let store: SnippetStore

    @State private var text = ""
    @State private var showsInvalidFormat = false
    @FocusState private var isEditorFocused: Bool

    private static let example = """
    Quick reply: Thanks! I’ll get back to you shortly.
    Email: hello@example.com
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .accessibilityLabel("Snippets to import")

                if text.isEmpty {
                    Text(Self.example)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))

            Button("Import") {
                let imported = store.importUncategorized(from: text)
                if imported == 0 {
                    showsInvalidFormat = true
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .illustratedBackground()
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Nothing to import", isPresented: $showsInvalidFormat) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use one line per snippet, with the name and phrase separated by a colon.")
        }
        .onAppear {
            isEditorFocused = true
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Alexx: Snippet Keyboard stores the snippets and categories you create on your device. The app and keyboard share them through an Apple App Group container.")
                Text("Alexx: Snippet Keyboard does not create accounts, use analytics or advertising, send snippets or typing activity to a server, or share your data with third parties.")
                Text("Full Access lets the keyboard read your personal snippets from the shared container. Without it, the keyboard offers built-in examples. The keyboard does not transmit what you type.")
                Text("You can delete snippets and categories in the app. Removing the app removes its locally stored data, subject to any device backups you control.")
                Text("For privacy questions, open an issue at https://github.com/mafonya/alexx/issues.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .illustratedBackground()
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
        .illustratedBackground()
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
