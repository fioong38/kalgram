import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers
import SGSwiftUI
import LegacyUI
import Display
import TelegramPresentationData
import AccountContext

// kalgram: the "Бейджики" screen in kalgram Pro, after Ghostgram's: switch, create,
// download by link or from Files, and a grid to pick from.

private final class KalgramBadgesModel: ObservableObject {
    let context: AccountContext
    @Published var items: [KalgramBadgeItem] = []
    @Published var images: [String: UIImage] = [:]
    @Published var selectedId: String
    @Published var isEnabled: Bool

    init(context: AccountContext) {
        self.context = context
        self.selectedId = KalgramBadgeStore.shared.selectedId
        self.isEnabled = KalgramBadgeStore.shared.isEnabled
        self.reload()
    }

    func reload() {
        let store = KalgramBadgeStore.shared
        let items = store.items()
        var images: [String: UIImage] = [:]
        for item in items {
            images[item.id] = store.image(for: item)
        }
        self.items = items
        self.images = images
        self.selectedId = store.selectedId
    }

    func select(_ item: KalgramBadgeItem) {
        KalgramBadgeStore.shared.select(item, context: self.context)
        self.selectedId = item.id
    }

    func setEnabled(_ value: Bool) {
        KalgramBadgeStore.shared.setEnabled(value, context: self.context)
        self.isEnabled = value
    }

    func delete(_ item: KalgramBadgeItem) {
        KalgramBadgeStore.shared.delete(id: item.id)
        KalgramBadgeStore.shared.apply(context: self.context)
        self.reload()
    }

    // Saves an edited or imported badge and puts it in use
    func added(_ file: KalgramBadgeFile) {
        self.reload()
        if let item = self.items.first(where: { $0.id == file.document.id }) {
            self.select(item)
        }
    }
}

private struct KalgramBadgeEditing: Identifiable {
    let id = UUID()
    let file: KalgramBadgeFile?
}

private struct KalgramBadgesView: View {
    @ObservedObject var model: KalgramBadgesModel
    @Environment(\.colorScheme) var colorScheme
    @State var editing: KalgramBadgeEditing?
    let downloadByLink: () -> Void
    let importFromFiles: () -> Void

    private var columns: [SwiftUI.GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16.0), count: 2)
    }

    private var cardColor: Color {
        Color(colorScheme == .dark ? UIColor.secondarySystemBackground : UIColor.systemBackground)
    }

    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14.0) {
                Image(systemName: icon)
                    .font(.system(size: 22.0))
                    .frame(width: 28.0)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding()
            .background(cardColor)
            .cornerRadius(16.0)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16.0) {
                Toggle("Показывать бейджик", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
                    .font(.headline)
                    .padding()
                    .background(cardColor)
                    .cornerRadius(16.0)

                actionRow(icon: "plus.circle.fill", title: "Создать свой бейдж", subtitle: "Фото, текст, фон — с живым предпросмотром", action: {
                    editing = KalgramBadgeEditing(file: nil)
                })
                actionRow(icon: "arrow.down.circle.fill", title: "Скачать бейдж по ссылке", subtitle: "Картинка или файл бейджа — расширение не важно", action: downloadByLink)
                actionRow(icon: "folder.fill", title: "Открыть из Файлов", subtitle: "Файл .ggbadge из Ghostgram или картинка", action: importFromFiles)

                LazyVGrid(columns: columns, alignment: .center, spacing: 16.0) {
                    ForEach(model.items) { item in
                        Button {
                            model.select(item)
                        } label: {
                            VStack(spacing: 8.0) {
                                ZStack {
                                    Capsule().fill(Color.black).frame(height: 50.0)
                                    if let image = model.images[item.id] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 40.0)
                                    }
                                }
                                Text(item.name).font(.footnote).lineLimit(1)
                                if item.isCustom {
                                    Text("Изменить")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                        .onTapGesture {
                                            editing = KalgramBadgeEditing(file: KalgramBadgeStore.shared.file(id: item.id))
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(cardColor)
                            .cornerRadius(16.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16.0)
                                    .stroke(model.selectedId == item.id ? Color.accentColor : Color.clear, lineWidth: 3.0)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if item.isCustom {
                                Button("Удалить") {
                                    model.delete(item)
                                }
                            }
                        }
                    }
                }

                Text("Бейдж стоит внутри Dynamic Island: вживую его закрывает островок, а на скриншотах он виден вместо островка. Свои бейджи — долгий тап, чтобы удалить.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20.0)
            .padding(.vertical, 24.0)
        }
        .background(Color(colorScheme == .light ? UIColor.secondarySystemBackground : UIColor.systemBackground).ignoresSafeArea())
        .sheet(item: $editing) { editing in
            KalgramBadgeEditorView(initial: editing.file, onSave: { file in
                KalgramBadgeStore.shared.save(file)
                model.added(file)
                self.editing = nil
            }, onCancel: {
                self.editing = nil
            })
        }
    }
}

private struct KalgramBadgeEditorView: View {
    let onSave: (KalgramBadgeFile) -> Void
    let onCancel: () -> Void

    private let documentId: String
    private let createdAt: String?
    // Layers of an imported badge the editor does not show, kept as they are
    private let otherLayers: [KalgramBadgeLayer]

    @State private var name: String
    @State private var backgroundKind: Int
    @State private var backgroundColor: Color
    @State private var backgroundImage: Data?
    @State private var cornerRadius: Double

    @State private var text: String
    @State private var textColor: Color
    @State private var fontSize: Double
    @State private var weight: String
    @State private var isRounded: Bool
    @State private var strokeWidth: Double
    @State private var strokeColor: Color
    @State private var textOffsetX: Double
    @State private var textOffsetY: Double

    @State private var layerImage: Data?
    @State private var layerScale: Double
    @State private var layerOffsetX: Double

    private static let weights: [(String, String)] = [("regular", "Обычный"), ("semibold", "Полужирный"), ("bold", "Жирный"), ("heavy", "Толстый")]

    init(initial: KalgramBadgeFile?, onSave: @escaping (KalgramBadgeFile) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        let document = initial?.document
        let assets = initial?.assets ?? [:]
        self.documentId = document?.id ?? "custom.\(UUID().uuidString)"
        self.createdAt = document?.createdAt

        var textLayer: (KalgramBadgeLayer, KalgramBadgeText)?
        var imageLayer: (KalgramBadgeLayer, Data?)?
        var other: [KalgramBadgeLayer] = []
        for layer in document?.layers ?? [] {
            switch layer.content {
            case let .text(value) where textLayer == nil:
                textLayer = (layer, value)
            case let .image(ref) where imageLayer == nil:
                imageLayer = (layer, assets[ref.assetId])
            default:
                other.append(layer)
            }
        }
        self.otherLayers = other

        self._name = State(initialValue: document?.name ?? "Мой бейдж")
        switch document?.background {
        case let .color(color):
            self._backgroundKind = State(initialValue: 1)
            self._backgroundColor = State(initialValue: Color(color.uiColor))
            self._backgroundImage = State(initialValue: nil)
        case let .image(ref):
            self._backgroundKind = State(initialValue: 2)
            self._backgroundColor = State(initialValue: Color.black)
            self._backgroundImage = State(initialValue: assets[ref.assetId])
        default:
            self._backgroundKind = State(initialValue: document == nil ? 1 : 0)
            self._backgroundColor = State(initialValue: Color.black)
            self._backgroundImage = State(initialValue: nil)
        }
        self._cornerRadius = State(initialValue: Double(document?.cornerRadius ?? 11.0))

        let textValue = textLayer?.1 ?? KalgramBadgeText(string: document == nil ? "kalgram" : "")
        self._text = State(initialValue: textValue.string)
        self._textColor = State(initialValue: Color(textValue.color.uiColor))
        self._fontSize = State(initialValue: Double(textValue.fontSize))
        self._weight = State(initialValue: textValue.weight)
        self._isRounded = State(initialValue: textValue.isRounded)
        self._strokeWidth = State(initialValue: Double(textValue.strokeWidth))
        self._strokeColor = State(initialValue: Color(textValue.strokeColor.uiColor))
        let textOffset = textLayer?.0.offset ?? [0.0, 0.0]
        self._textOffsetX = State(initialValue: Double(textOffset.first ?? 0.0))
        self._textOffsetY = State(initialValue: Double(textOffset.count > 1 ? textOffset[1] : 0.0))

        self._layerImage = State(initialValue: imageLayer?.1)
        self._layerScale = State(initialValue: Double(imageLayer?.0.scale ?? 1.0))
        self._layerOffsetX = State(initialValue: Double(imageLayer?.0.offset.first ?? -30.0))
    }

    private var file: KalgramBadgeFile {
        var assets: [String: Data] = [:]
        let background: KalgramBadgeBackground
        switch backgroundKind {
        case 1:
            background = .color(KalgramBadgeColor(UIColor(backgroundColor)))
        case 2:
            if let backgroundImage {
                assets["background"] = backgroundImage
                background = .image(KalgramBadgeImageRef(assetId: "background"))
            } else {
                background = .transparent
            }
        default:
            background = .transparent
        }
        var layers: [KalgramBadgeLayer] = []
        if let layerImage {
            assets["layer"] = layerImage
            layers.append(KalgramBadgeLayer(content: .image(KalgramBadgeImageRef(assetId: "layer")), offset: [CGFloat(layerOffsetX), 0.0], scale: CGFloat(layerScale)))
        }
        if !text.isEmpty {
            layers.append(KalgramBadgeLayer(content: .text(KalgramBadgeText(string: text, color: KalgramBadgeColor(UIColor(textColor)), fontSize: CGFloat(fontSize), weight: weight, isRounded: isRounded, strokeColor: KalgramBadgeColor(UIColor(strokeColor)), strokeWidth: CGFloat(strokeWidth))), offset: [CGFloat(textOffsetX), CGFloat(textOffsetY)]))
        }
        layers.append(contentsOf: otherLayers)
        var document = KalgramBadgeDocument(id: documentId, name: name.isEmpty ? "Мой бейдж" : name, background: background, cornerRadius: CGFloat(cornerRadius), layers: layers)
        if let createdAt {
            document.createdAt = createdAt
        }
        return KalgramBadgeFile(document: document, assets: assets)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text(title).font(.footnote).foregroundColor(.secondary)
            Slider(value: value, in: range)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Capsule().fill(Color.black).frame(width: 280.0, height: 90.0)
                            Image(uiImage: KalgramBadgeRenderer.render(file))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 248.0)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8.0)
                    TextField("Название", text: $name)
                }

                Section(header: Text("Фон")) {
                    Picker("Фон", selection: $backgroundKind) {
                        Text("Прозрачный").tag(0)
                        Text("Цвет").tag(1)
                        Text("Фото").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if backgroundKind == 1 {
                        ColorPicker("Цвет фона", selection: $backgroundColor, supportsOpacity: true)
                    }
                    if backgroundKind == 2 {
                        Button(backgroundImage == nil ? "Выбрать фото" : "Сменить фото") {
                            KalgramImagePicker.shared.pick(maxSide: 600.0, completion: { image in
                                backgroundImage = image.jpegData(compressionQuality: 0.9)
                            })
                        }
                    }
                    slider("Скругление", value: $cornerRadius, range: 0.0 ... 11.0)
                }

                Section(header: Text("Текст")) {
                    TextField("Текст", text: $text)
                    ColorPicker("Цвет текста", selection: $textColor, supportsOpacity: false)
                    Picker("Толщина", selection: $weight) {
                        ForEach(0 ..< KalgramBadgeEditorView.weights.count, id: \.self) { index in
                            Text(KalgramBadgeEditorView.weights[index].1).tag(KalgramBadgeEditorView.weights[index].0)
                        }
                    }
                    Toggle("Скруглённый шрифт", isOn: $isRounded)
                    slider("Размер", value: $fontSize, range: 6.0 ... 20.0)
                    slider("Обводка", value: $strokeWidth, range: 0.0 ... 4.0)
                    if strokeWidth > 0.0 {
                        ColorPicker("Цвет обводки", selection: $strokeColor, supportsOpacity: false)
                    }
                    slider("Сдвиг влево / вправо", value: $textOffsetX, range: -45.0 ... 45.0)
                    slider("Сдвиг вверх / вниз", value: $textOffsetY, range: -11.0 ... 11.0)
                }

                Section(header: Text("Картинка-слой")) {
                    Button(layerImage == nil ? "Добавить картинку" : "Сменить картинку") {
                        KalgramImagePicker.shared.pick(maxSide: 300.0, completion: { image in
                            layerImage = image.pngData()
                        })
                    }
                    if layerImage != nil {
                        slider("Размер", value: $layerScale, range: 0.3 ... 2.0)
                        slider("Сдвиг влево / вправо", value: $layerOffsetX, range: -45.0 ... 45.0)
                        Button("Убрать картинку") {
                            layerImage = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Бейдж")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(file)
                    }
                }
            }
        }
    }
}

// Picks a file in Files and hands over its contents
private final class KalgramDocumentPicker: NSObject, UIDocumentPickerDelegate {
    static let shared = KalgramDocumentPicker()

    private var completion: ((Data, String) -> Void)?

    func pick(completion: @escaping (Data, String) -> Void) {
        guard let top = KalgramImagePicker.topViewController() else {
            return
        }
        self.completion = completion
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        top.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first, let data = try? Data(contentsOf: url) {
            self.completion?(data, url.deletingPathExtension().lastPathComponent)
        }
        self.completion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.completion = nil
    }
}

public func kalgramBadgesController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let legacyController = LegacySwiftUIController(
        presentation: .navigation,
        theme: theme,
        strings: presentationData.strings
    )
    legacyController.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
    legacyController.title = "Бейджики"

    let model = KalgramBadgesModel(context: context)

    let showMessage: (String) -> Void = { text in
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        KalgramImagePicker.topViewController()?.present(alert, animated: true)
    }
    let imported: (Data, String) -> Void = { data, name in
        if let file = KalgramBadgeStore.shared.importBadge(data: data, name: name) {
            model.added(file)
        } else {
            showMessage("Это не картинка и не файл бейджа")
        }
    }

    let downloadByLink: () -> Void = {
        let alert = UIAlertController(title: "Скачать бейдж", message: "Ссылка на картинку или файл бейджа", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://…"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Скачать", style: .default, handler: { [weak alert] _ in
            guard let string = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: string), url.scheme == "https" || url.scheme == "http" else {
                showMessage("Неверная ссылка")
                return
            }
            URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                DispatchQueue.main.async {
                    if let data {
                        imported(data, url.deletingPathExtension().lastPathComponent)
                    } else {
                        showMessage("Не удалось скачать")
                    }
                }
            }).resume()
        }))
        KalgramImagePicker.topViewController()?.present(alert, animated: true)
    }

    let importFromFiles: () -> Void = {
        KalgramDocumentPicker.shared.pick(completion: { data, name in
            imported(data, name)
        })
    }

    let swiftUIView = SGSwiftUIView<KalgramBadgesView>(
        legacyController: legacyController,
        manageSafeArea: true,
        content: {
            KalgramBadgesView(model: model, downloadByLink: downloadByLink, importFromFiles: importFromFiles)
        }
    )
    let controller = UIHostingController(rootView: swiftUIView, ignoreSafeArea: true)
    legacyController.bind(controller: controller)
    return legacyController
}
