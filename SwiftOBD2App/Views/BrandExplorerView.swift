//
//  BrandExplorerView.swift
//  SMARTOBD2
//
//  Created by ChatGPT on 11/30/25.
//

import SwiftUI

final class BrandExplorerViewModel: ObservableObject {
    @Published private(set) var manufacturers: [Manufacturer] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    init() {
        loadManufacturers()
    }

    func loadManufacturers() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let url = Bundle.main.url(forResource: "Cars", withExtension: "json") else {
                    throw URLError(.fileDoesNotExist)
                }
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Manufacturer].self, from: data)

                DispatchQueue.main.async {
                    self.manufacturers = decoded
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.manufacturers = []
                    self.errorMessage = "Araç verileri yüklenemedi. Lütfen tekrar deneyin."
                    self.isLoading = false
                }
            }
        }
    }
}

struct BrandExplorerView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case random = "Karışık"
        case alphabetical = "A-Z"
        case reverseAlphabetical = "Z-A"

        var id: String { rawValue }
    }

    @Binding var isDemoMode: Bool

    @StateObject private var viewModel = BrandExplorerViewModel()
    @State private var searchText = ""
    @State private var sortOption: SortOption = .random
    @State private var randomizedManufacturers: [Manufacturer] = []

    private var filteredManufacturers: [Manufacturer] {
        var source: [Manufacturer]
        switch sortOption {
        case .random:
            source = randomizedManufacturers
        case .alphabetical:
            source = viewModel.manufacturers.sorted { $0.make.localizedCaseInsensitiveCompare($1.make) == .orderedAscending }
        case .reverseAlphabetical:
            source = viewModel.manufacturers.sorted { $0.make.localizedCaseInsensitiveCompare($1.make) == .orderedDescending }
        }

        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return source
        }

        return source.filter {
            $0.make.localizedCaseInsensitiveContains(searchText.trimmingCharacters(in: .whitespaces))
        }
    }

    var body: some View {
        ZStack {
            BackgroundView(isDemoMode: $isDemoMode)
            VStack(spacing: 16) {
                header
                searchField
                sortControls
                content
            }
            .padding()
        }
        .navigationTitle("Marka Rehberi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if randomizedManufacturers.isEmpty {
                randomizedManufacturers = viewModel.manufacturers.shuffled()
            }
        }
        .onChange(of: viewModel.manufacturers) { newValue in
            guard !newValue.isEmpty else { return }
            randomizedManufacturers = newValue.shuffled()
        }
        .onChange(of: sortOption) { option in
            if option == .random {
                randomizedManufacturers = viewModel.manufacturers.shuffled()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tüm araç markaları tek ekranda")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            Text("EVScanner tarzında kişisel kullanım için tüm markaları karışık olarak inceleyebilir, dilersen arama yaparak hızlıca filtreleyebilirsin.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Marka ara", text: $searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sortControls: some View {
        VStack(spacing: 10) {
            Picker("Sıralama", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            if sortOption == .random {
                Button {
                    randomizedManufacturers = viewModel.manufacturers.shuffled()
                } label: {
                    Label("Yeniden Karıştır", systemName: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(.white)
                .padding(.top, 40)
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Button("Tekrar dene") {
                    viewModel.loadManufacturers()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredManufacturers, id: \.self) { manufacturer in
                        BrandCard(make: manufacturer.make, modelCount: manufacturer.models.count)
                    }
                }
                .padding(.vertical, 10)

                Text("\(filteredManufacturers.count) marka gösteriliyor")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct BrandCard: View {
    let make: String
    let modelCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(make)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text("\(modelCount) model")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Image(systemName: "car.fill")
                .foregroundColor(.white.opacity(0.6))
                .imageScale(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.cyclamen.opacity(0.9), Color.blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        BrandExplorerView(isDemoMode: .constant(false))
    }
}
