import SwiftUI
import UIKit

private let appGroupIdentifier = "group.com.michaelabramovpersonalteam.Keyboard"
private let libraryFilename = "snippets.json"

private struct KeyboardSnippet: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var collection: String
    var icon: String?
    var isFavorite: Bool
    var createdAt: Date
}

final class KeyboardViewController: UIInputViewController {
    private var host: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = KeyboardRootView(
            snippets: loadSnippets(),
            insertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            deleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            nextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 300)
        ])

        host.didMove(toParent: self)
        self.host = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        host?.rootView.snippets = loadSnippets()
    }

    private func loadSnippets() -> [KeyboardSnippet] {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ),
        let data = try? Data(contentsOf: container.appendingPathComponent(libraryFilename)),
        let snippets = try? JSONDecoder().decode([KeyboardSnippet].self, from: data) else {
            return []
        }
        return snippets
    }
}

private struct KeyboardRootView: View {
    var snippets: [KeyboardSnippet]
    let insertText: (String) -> Void
    let deleteBackward: () -> Void
    let nextKeyboard: () -> Void

    @State private var query = ""
    @State private var selectedCollection: String?

    private var collections: [String] {
        Array(Set(snippets.map(\.collection))).sorted()
    }

    private var visibleSnippets: [KeyboardSnippet] {
        snippets
            .filter { snippet in
                let matchesCollection = selectedCollection == nil || snippet.collection == selectedCollection
                let matchesQuery = query.isEmpty ||
                    snippet.title.localizedStandardContains(query) ||
                    snippet.content.localizedStandardContains(query)
                return matchesCollection && matchesQuery
            }
            .sorted {
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite
                }
                return $0.createdAt > $1.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search snippets", text: $query)
                    .textFieldStyle(.roundedBorder)

                Button("Delete", systemImage: "delete.left", action: deleteBackward)
                    .labelStyle(.iconOnly)
                    .buttonStyle(KeyboardUtilityButtonStyle())

                Button("Next Keyboard", systemImage: "globe", action: nextKeyboard)
                    .labelStyle(.iconOnly)
                    .buttonStyle(KeyboardUtilityButtonStyle())
            }

            if !collections.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        collectionButton("All", collection: nil)
                        ForEach(collections, id: \.self) { collection in
                            collectionButton(collection, collection: collection)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
            }

            if visibleSnippets.isEmpty {
                ContentUnavailableView(
                    snippets.isEmpty ? "No snippets yet" : "No matches",
                    systemImage: snippets.isEmpty ? "text.badge.plus" : "magnifyingglass",
                    description: Text(snippets.isEmpty ? "Create snippets in the Snippet app." : "Try another search or collection.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 7),
                            GridItem(.flexible(), spacing: 7)
                        ],
                        spacing: 7
                    ) {
                        ForEach(visibleSnippets) { snippet in
                            Button {
                                insertText(snippet.content)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(snippet.icon ?? (snippet.isFavorite ? "⭐️" : "💬"))
                                            .font(.caption)
                                        Text(snippet.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }

                                    Text(snippet.content)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                                .background(.background, in: .rect(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(snippet.title), \(snippet.content)")
                            .accessibilityHint("Inserts this snippet")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .ignoresSafeArea(edges: .top)
    }

    private func collectionButton(_ title: String, collection: String?) -> some View {
        let isSelected = selectedCollection == collection
        return Button(title) {
            selectedCollection = collection
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(isSelected ? Color.indigo : Color(uiColor: .tertiarySystemFill), in: .capsule)
        .foregroundStyle(isSelected ? .white : .primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct KeyboardUtilityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Color(uiColor: .systemBackground).opacity(configuration.isPressed ? 0.65 : 1), in: .rect(cornerRadius: 8))
    }
}
