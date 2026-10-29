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
    @State private var gradientStart: Color
    @State private var gradientEnd: Color
    @State private var gradientAngle: Double
    @State private var backgroundImage: Data?
    @State private var backgroundScale: Double
    @State private var backgroundOffsetX: Double
    @State private var backgroundOffsetY: Double
    @State private var backgroundOpacity: Double
    @State private var cornerRadius: Double
    @State private var borderWidth: Double
    @State private var borderColor: Color

    @State private var text: String
    @State private var textColor: Color
    @State private var fontSize: Double
    @State private var weight: String
    @State private var design: String
    @State private var isItalic: Bool
    @State private var tracking: Double
    @State private var strokeWidth: Double
    @State private var strokeColor: Color
    @State private var shadowRadius: Double
    @State private var shadowColor: Color
    @State private var textOffsetX: Double
    @State private var textOffsetY: Double
    @State private var textRotation: Double
    @State private var textOpacity: Double

    @State private var layerImage: Data?
    @State private var layerScale: Double
    @State private var layerOffsetX: Double
    @State private var layerOffsetY: Double
    @State private var layerRotation: Double
    @State private var layerOpacity: Double

    // What a drag or a pinch on the preview moves: 0 text, 1 picture, 2 background
    @State private var target: Int
    @State private var gestureBase: [Double]?

    private static let weights: [(String, String)] = [
        ("ultraLight", "Сверхтонкий"),
        ("thin", "Тонкий"),
        ("light", "Светлый"),
        ("regular", "Обычный"),
        ("medium", "Средний"),
        ("semibold", "Полужирный"),
        ("bold", "Жирный"),
        ("heavy", "Толстый"),
        ("black", "Сверхжирный")
    ]
    private static let designs: [(String, String)] = [("default", "Обычный"), ("rounded", "Округлый"), ("serif", "С засечками"), ("monospaced", "Моноширинный")]

    // The preview draws the badge this many times larger than on the phone
    private static let previewScale: CGFloat = 3.4

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
        var kind = document == nil ? 1 : 0
        var color = Color(red: 0.165, green: 0.671, blue: 0.933)
        var start = Color(red: 0.55, green: 0.25, blue: 0.95)
        var end = Color(red: 0.95, green: 0.3, blue: 0.55)
        var angle = 0.0
        var image: Data?
        switch document?.background {
        case let .color(value):
            kind = 1
            color = Color(value.uiColor)
        case let .gradient(value):
            kind = 2
            if let first = value.colors.first {
                start = Color(first.uiColor)
            }
            if let last = value.colors.last {
                end = Color(last.uiColor)
            }
            angle = Double(value.angle)
        case let .image(ref):
            kind = 3
            image = assets[ref.assetId]
        default:
            break
        }
        self._backgroundKind = State(initialValue: kind)
        self._backgroundColor = State(initialValue: color)
        self._gradientStart = State(initialValue: start)
        self._gradientEnd = State(initialValue: end)
        self._gradientAngle = State(initialValue: angle)
        self._backgroundImage = State(initialValue: image)
        self._backgroundScale = State(initialValue: Double(document?.backgroundScale ?? 1.0))
        let backgroundOffset = document?.backgroundOffset ?? [0.0, 0.0]
        self._backgroundOffsetX = State(initialValue: Double(backgroundOffset.first ?? 0.0))
        self._backgroundOffsetY = State(initialValue: Double(backgroundOffset.count > 1 ? backgroundOffset[1] : 0.0))
        self._backgroundOpacity = State(initialValue: Double(document?.backgroundOpacity ?? 1.0))
        self._cornerRadius = State(initialValue: Double(document?.cornerRadius ?? 11.0))
        self._borderWidth = State(initialValue: Double(document?.borderWidth ?? 0.0))
        self._borderColor = State(initialValue: Color(document?.borderColor.uiColor ?? .white))

        let textValue = textLayer?.1 ?? KalgramBadgeText(string: document == nil ? "kalgram" : "", fontSize: 13.0)
        self._text = State(initialValue: textValue.string)
        self._textColor = State(initialValue: Color(textValue.color.uiColor))
        self._fontSize = State(initialValue: Double(textValue.fontSize))
        self._weight = State(initialValue: textValue.weight)
        let designValue: String
        switch textValue.design {
        case "serif", "monospaced":
            designValue = textValue.design
        default:
            designValue = textValue.isRounded ? "rounded" : "default"
        }
        self._design = State(initialValue: designValue)
        self._isItalic = State(initialValue: textValue.isItalic)
        self._tracking = State(initialValue: Double(textValue.tracking))
        self._strokeWidth = State(initialValue: Double(textValue.strokeWidth))
        self._strokeColor = State(initialValue: Color(textValue.strokeColor.uiColor))
        self._shadowRadius = State(initialValue: Double(textValue.shadowRadius))
        self._shadowColor = State(initialValue: Color(textValue.shadowColor.uiColor))
        let textOffset = textLayer?.0.offset ?? [0.0, 0.0]
        self._textOffsetX = State(initialValue: Double(textOffset.first ?? 0.0))
        self._textOffsetY = State(initialValue: Double(textOffset.count > 1 ? textOffset[1] : 0.0))
        self._textRotation = State(initialValue: Double(textLayer?.0.rotation ?? 0.0))
        self._textOpacity = State(initialValue: Double(textLayer?.0.opacity ?? 1.0))

        self._layerImage = State(initialValue: imageLayer?.1)
        self._layerScale = State(initialValue: Double(imageLayer?.0.scale ?? 1.0))
        let layerOffset = imageLayer?.0.offset ?? [-30.0, 0.0]
        self._layerOffsetX = State(initialValue: Double(layerOffset.first ?? -30.0))
        self._layerOffsetY = State(initialValue: Double(layerOffset.count > 1 ? layerOffset[1] : 0.0))
        self._layerRotation = State(initialValue: Double(imageLayer?.0.rotation ?? 0.0))
        self._layerOpacity = State(initialValue: Double(imageLayer?.0.opacity ?? 1.0))

        self._target = State(initialValue: 0)
        self._gestureBase = State(initialValue: nil)
    }

    private var file: KalgramBadgeFile {
        var assets: [String: Data] = [:]
        let background: KalgramBadgeBackground
        switch backgroundKind {
        case 1:
            background = .color(KalgramBadgeColor(UIColor(backgroundColor)))
        case 2:
            background = .gradient(KalgramBadgeGradient(colors: [KalgramBadgeColor(UIColor(gradientStart)), KalgramBadgeColor(UIColor(gradientEnd))], angle: CGFloat(gradientAngle)))
        case 3:
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
            layers.append(KalgramBadgeLayer(content: .image(KalgramBadgeImageRef(assetId: "layer")), offset: [CGFloat(layerOffsetX), CGFloat(layerOffsetY)], opacity: CGFloat(layerOpacity), rotation: CGFloat(layerRotation), scale: CGFloat(layerScale)))
        }
        if !text.isEmpty {
            let value = KalgramBadgeText(
                string: text,
                color: KalgramBadgeColor(UIColor(textColor)),
                fontSize: CGFloat(fontSize),
                weight: weight,
                isRounded: design == "rounded",
                strokeColor: KalgramBadgeColor(UIColor(strokeColor)),
                strokeWidth: CGFloat(strokeWidth),
                tracking: CGFloat(tracking),
                design: design,
                isItalic: isItalic,
                shadowColor: KalgramBadgeColor(UIColor(shadowColor)),
                shadowRadius: CGFloat(shadowRadius)
            )
            layers.append(KalgramBadgeLayer(content: .text(value), offset: [CGFloat(textOffsetX), CGFloat(textOffsetY)], opacity: CGFloat(textOpacity), rotation: CGFloat(textRotation)))
        }
        layers.append(contentsOf: otherLayers)
        var document = KalgramBadgeDocument(
            id: documentId,
            name: name.isEmpty ? "Мой бейдж" : name,
            background: background,
            cornerRadius: CGFloat(cornerRadius),
            layers: layers,
            backgroundScale: CGFloat(backgroundScale),
            backgroundOffset: [CGFloat(backgroundOffsetX), CGFloat(backgroundOffsetY)],
            backgroundOpacity: CGFloat(backgroundOpacity),
            borderWidth: CGFloat(borderWidth),
            borderColor: KalgramBadgeColor(UIColor(borderColor))
        )
        if let createdAt {
            document.createdAt = createdAt
        }
        return KalgramBadgeFile(document: document, assets: assets)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String = "%.0f") -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(title).font(.footnote).foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.footnote.monospacedDigit()).foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    // The values a gesture changes for the current target: x, y and size
    private var targetValues: [Double] {
        switch target {
        case 1:
            return [layerOffsetX, layerOffsetY, layerScale]
        case 2:
            return [backgroundOffsetX, backgroundOffsetY, backgroundScale]
        default:
            return [textOffsetX, textOffsetY, fontSize]
        }
    }

    private func setTargetValues(x: Double, y: Double, size: Double) {
        let clampX = max(-93.0, min(93.0, x))
        let clampY = max(-44.0, min(44.0, y))
        switch target {
        case 1:
            layerOffsetX = clampX
            layerOffsetY = clampY
            layerScale = max(0.1, min(6.0, size))
        case 2:
            backgroundOffsetX = clampX
            backgroundOffsetY = clampY
            backgroundScale = max(0.2, min(8.0, size))
        default:
            textOffsetX = clampX
            textOffsetY = clampY
            fontSize = max(4.0, min(40.0, size))
        }
    }

    private var preview: some View {
        let scale = KalgramBadgeEditorView.previewScale
        let size = KalgramBadgeRenderer.size
        let gesture = SimultaneousGesture(DragGesture(minimumDistance: 1.0), MagnificationGesture())
            .onChanged { value in
                let base = gestureBase ?? targetValues
                if gestureBase == nil {
                    gestureBase = base
                }
                let translation = value.first?.translation ?? .zero
                let magnification = Double(value.second ?? 1.0)
                setTargetValues(x: base[0] + Double(translation.width / scale), y: base[1] + Double(translation.height / scale), size: base[2] * magnification)
            }
            .onEnded { _ in
                gestureBase = nil
            }
        return VStack(spacing: 10.0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22.0)
                    .fill(Color.black)
                    .frame(height: size.height * scale + 40.0)
                Image(uiImage: KalgramBadgeRenderer.render(file))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width * scale, height: size.height * scale)
            }
            .contentShape(Rectangle())
            .gesture(gesture)
            Picker("Двигать", selection: $target) {
                Text("Текст").tag(0)
                Text("Картинку").tag(1)
                Text("Фон").tag(2)
            }
            .pickerStyle(.segmented)
            Text("Тяни по превью, чтобы двигать, и щипай двумя пальцами, чтобы менять размер")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 10.0)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func applyPreset(_ index: Int) {
        backgroundOpacity = 1.0
        borderWidth = 0.0
        shadowRadius = 0.0
        strokeWidth = 0.0
        isItalic = false
        tracking = 0.0
        switch index {
        case 1:
            backgroundKind = 1
            backgroundColor = .black
            textColor = .white
            borderWidth = 1.0
            borderColor = .white
            design = "monospaced"
            weight = "bold"
        case 2:
            backgroundKind = 2
            gradientStart = Color(red: 0.55, green: 0.25, blue: 0.95)
            gradientEnd = Color(red: 0.95, green: 0.3, blue: 0.55)
            gradientAngle = 0.0
            textColor = .white
            design = "rounded"
            weight = "heavy"
        case 3:
            backgroundKind = 0
            textColor = Color(red: 0.2, green: 1.0, blue: 0.6)
            shadowColor = Color(red: 0.2, green: 1.0, blue: 0.6)
            shadowRadius = 4.0
            design = "rounded"
            weight = "bold"
        case 4:
            backgroundKind = 2
            gradientStart = Color(red: 1.0, green: 0.84, blue: 0.3)
            gradientEnd = Color(red: 0.75, green: 0.5, blue: 0.1)
            gradientAngle = 90.0
            textColor = .black
            design = "serif"
            weight = "bold"
            isItalic = true
        default:
            backgroundKind = 1
            backgroundColor = Color(red: 0.165, green: 0.671, blue: 0.933)
            textColor = .white
            design = "rounded"
            weight = "bold"
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Название", text: $name)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8.0) {
                    ForEach(Array(["Telegram", "Терминал", "Закат", "Неон", "Золото"].enumerated()), id: \.offset) { index, title in
                        Button(title) {
                            applyPreset(index)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var backgroundSection: some View {
        Section(header: Text("Фон")) {
            Picker("Фон", selection: $backgroundKind) {
                Text("Нет").tag(0)
                Text("Цвет").tag(1)
                Text("Градиент").tag(2)
                Text("Фото").tag(3)
            }
            .pickerStyle(.segmented)
            if backgroundKind == 1 {
                ColorPicker("Цвет фона", selection: $backgroundColor, supportsOpacity: true)
            }
            if backgroundKind == 2 {
                ColorPicker("Начало", selection: $gradientStart, supportsOpacity: true)
                ColorPicker("Конец", selection: $gradientEnd, supportsOpacity: true)
                slider("Угол", value: $gradientAngle, range: 0.0 ... 360.0, format: "%.0f°")
            }
            if backgroundKind == 3 {
                Button(backgroundImage == nil ? "Выбрать фото" : "Сменить фото") {
                    KalgramImagePicker.shared.pickOriginal(completion: { data in
                        backgroundImage = data
                        backgroundScale = 1.0
                        backgroundOffsetX = 0.0
                        backgroundOffsetY = 0.0
                        target = 2
                    })
                }
                if backgroundImage != nil {
                    slider("Масштаб", value: $backgroundScale, range: 0.2 ... 8.0, format: "%.2f×")
                    slider("Сдвиг влево / вправо", value: $backgroundOffsetX, range: -93.0 ... 93.0)
                    slider("Сдвиг вверх / вниз", value: $backgroundOffsetY, range: -44.0 ... 44.0)
                    slider("Непрозрачность", value: $backgroundOpacity, range: 0.0 ... 1.0, format: "%.2f")
                }
            }
            slider("Скругление", value: $cornerRadius, range: 0.0 ... 11.0)
            slider("Рамка", value: $borderWidth, range: 0.0 ... 4.0, format: "%.1f")
            if borderWidth > 0.0 {
                ColorPicker("Цвет рамки", selection: $borderColor, supportsOpacity: true)
            }
        }
    }

    private var textSection: some View {
        Section(header: Text("Текст")) {
            TextField("Текст (можно эмодзи)", text: $text)
            ColorPicker("Цвет текста", selection: $textColor, supportsOpacity: true)
            Picker("Шрифт", selection: $design) {
                ForEach(0 ..< KalgramBadgeEditorView.designs.count, id: \.self) { index in
                    Text(KalgramBadgeEditorView.designs[index].1).tag(KalgramBadgeEditorView.designs[index].0)
                }
            }
            Picker("Толщина", selection: $weight) {
                ForEach(0 ..< KalgramBadgeEditorView.weights.count, id: \.self) { index in
                    Text(KalgramBadgeEditorView.weights[index].1).tag(KalgramBadgeEditorView.weights[index].0)
                }
            }
            Toggle("Курсив", isOn: $isItalic)
            slider("Размер", value: $fontSize, range: 4.0 ... 40.0)
            slider("Межбуквенный интервал", value: $tracking, range: -3.0 ... 10.0, format: "%.1f")
            slider("Обводка", value: $strokeWidth, range: 0.0 ... 6.0, format: "%.1f")
            if strokeWidth > 0.0 {
                ColorPicker("Цвет обводки", selection: $strokeColor, supportsOpacity: false)
            }
            slider("Свечение / тень", value: $shadowRadius, range: 0.0 ... 12.0, format: "%.1f")
            if shadowRadius > 0.0 {
                ColorPicker("Цвет свечения", selection: $shadowColor, supportsOpacity: true)
            }
            slider("Сдвиг влево / вправо", value: $textOffsetX, range: -93.0 ... 93.0)
            slider("Сдвиг вверх / вниз", value: $textOffsetY, range: -44.0 ... 44.0)
            slider("Поворот", value: $textRotation, range: -180.0 ... 180.0, format: "%.0f°")
            slider("Непрозрачность", value: $textOpacity, range: 0.0 ... 1.0, format: "%.2f")
        }
    }

    private var layerSection: some View {
        Section(header: Text("Картинка-слой"), footer: Text("Картинка берётся в исходном разрешении (до 4096 px), поэтому при увеличении остаётся чёткой.")) {
            Button(layerImage == nil ? "Добавить картинку" : "Сменить картинку") {
                KalgramImagePicker.shared.pickOriginal(completion: { data in
                    layerImage = data
                    target = 1
                })
            }
            if layerImage != nil {
                slider("Размер", value: $layerScale, range: 0.1 ... 6.0, format: "%.2f×")
                slider("Сдвиг влево / вправо", value: $layerOffsetX, range: -93.0 ... 93.0)
                slider("Сдвиг вверх / вниз", value: $layerOffsetY, range: -44.0 ... 44.0)
                slider("Поворот", value: $layerRotation, range: -180.0 ... 180.0, format: "%.0f°")
                slider("Непрозрачность", value: $layerOpacity, range: 0.0 ... 1.0, format: "%.2f")
                Button("Убрать картинку") {
                    layerImage = nil
                    if target == 1 {
                        target = 0
                    }
                }
                .foregroundColor(.red)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0.0) {
                preview
                Form {
                    nameSection
                    backgroundSection
                    textSection
                    layerSection
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
