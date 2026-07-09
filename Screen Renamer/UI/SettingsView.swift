import SwiftUI

struct SettingsView: View {
    @State private var template: NamingTemplate = NamingTemplate.stored

    private let previewContext = AppContext(
        timestamp: Date(),
        appName: "Google Chrome",
        windowTitle: "Design Review",
        tabName: "Design Review",
        browserDomain: "figma.com"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewSection
            Divider()
            fieldsSection
            Divider()
            separatorSection
            Divider()
            affixSection
            Divider()
            footerSection
        }
        .frame(width: 440)
        .onChange(of: template) { newValue in
            newValue.save()
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.headline)

            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                Text(previewFilename)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

            Text("Based on: Chrome window \u{201C}Design Review\u{201D} on figma.com")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var previewFilename: String {
        let url = URL(fileURLWithPath: "/tmp/Preview.png")
        return FilenameGenerator()
            .destinationURL(
                for: url,
                context: previewContext,
                ocrResult: nil,
                windowMetadata: nil,
                template: template,
                directoryURL: URL(fileURLWithPath: "/tmp")
            )
            .lastPathComponent
    }

    // MARK: - Active Fields

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fields")
                .font(.headline)

            Text("Included in the filename in this order. Drag the arrows to reorder.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Active field rows
            VStack(spacing: 0) {
                if template.fields.isEmpty {
                    Text("No fields selected \u{2014} filename will be \u{201C}Screenshot\u{201D}.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    ForEach(0 ..< template.fields.count, id: \.self) { index in
                        fieldRow(index: index)
                        if index < template.fields.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

            // Available fields to add
            if !availableFields.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                        ForEach(availableFields) { field in
                            Button {
                                template.fields.append(field)
                            } label: {
                                Label(field.displayName, systemImage: "plus")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func fieldRow(index: Int) -> some View {
        let field = template.fields[index]
        HStack(spacing: 10) {
            // Reorder buttons
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        template.fields.swapAt(index, index - 1)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 14)
                }
                .disabled(index == 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        template.fields.swapAt(index, index + 1)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 14)
                }
                .disabled(index == template.fields.count - 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Field label
            VStack(alignment: .leading, spacing: 1) {
                Text(field.displayName)
                    .font(.callout.weight(.medium))
                Text(field.subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Example value badge
            Text(field.exampleValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)

            // Remove button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    template.fields = template.fields.enumerated()
                        .filter { $0.offset != index }
                        .map(\.element)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var availableFields: [NamingField] {
        NamingField.allCases.filter { !template.fields.contains($0) }
    }

    // MARK: - Separator

    private var separatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Separator")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach([("_", "Underscore"), ("-", "Dash"), (".", "Period"), (" ", "Space")], id: \.0) { sep, label in
                    Button {
                        template.separator = sep
                    } label: {
                        VStack(spacing: 2) {
                            Text(sep == " " ? "·" : sep)
                                .font(.system(.body, design: .monospaced).weight(.medium))
                            Text(label)
                                .font(.system(size: 9))
                        }
                        .frame(width: 58, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .background(template.separator == sep ? Color.accentColor.opacity(0.12) : Color.clear)
                    .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $template.separator)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.system(.callout, design: .monospaced))
                }
            }
        }
        .padding()
    }

    // MARK: - Prefix / Suffix

    private var affixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Text")
                .font(.headline)

            Text("Fixed text added before or after every filename.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prefix")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Work_", text: $template.prefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 170)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Suffix")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g. _draft", text: $template.suffix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 170)
                }
            }
        }
        .padding()
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("Reset to Default") {
                withAnimation {
                    template = .default
                }
            }
        }
        .padding()
    }
}
