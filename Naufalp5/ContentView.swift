
import SwiftUI
import MapKit

struct GempaResponse: Codable {
    let Infogempa: InfoGempaSingle
}

struct InfoGempaSingle: Codable {
    let gempa: Gempa
}

struct GempasResponseList: Codable {
    let Infogempa: InfoGempaList
}

struct InfoGempaList: Codable {
    let gempa: [Gempa]
}

struct Gempa: Codable, Identifiable {
    var id: String { tanggal + jam }
    let tanggal: String
    let jam: String
    let lintang: String
    let bujur: String
    let magnitude: String
    let kedalaman: String
    let wilayah: String
    let potensi: String?
    let dirasakan: String?
    let shakemap: String?

    enum CodingKeys: String, CodingKey {
        case tanggal = "Tanggal"
        case jam = "Jam"
        case lintang = "Lintang"
        case bujur = "Bujur"
        case magnitude = "Magnitude"
        case kedalaman = "Kedalaman"
        case wilayah = "Wilayah"
        case potensi = "Potensi"
        case dirasakan = "Dirasakan"
        case shakemap = "Shakemap"
    }
}

class GempaViewModel: ObservableObject {
    @Published var gempaSingle: Gempa?
    @Published var gempaList: [Gempa] = []
    @Published var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var isLoading = false

    func fetchGempaSingle() {
        guard let url = URL(string: "https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json") else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(GempaResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.gempaSingle = decoded.Infogempa.gempa
                        self.coordinate = self.getCoordinate(from: decoded.Infogempa.gempa)
                    }
                } catch {
                    print("Decoding error single:", error)
                }
            }
        }.resume()
    }

    func fetchGempaList(from urlString: String, completion: @escaping ([Gempa]) -> Void) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(GempasResponseList.self, from: data)
                    DispatchQueue.main.async {
                        completion(decoded.Infogempa.gempa)
                    }
                } catch {
                    print("Decoding error list:", error)
                }
            }
        }.resume()
    }

    private func getCoordinate(from gempa: Gempa) -> CLLocationCoordinate2D {
        func parse(_ string: String) -> Double? {
            var cleaned = string.replacingOccurrences(of: " ", with: "")
            var multiplier = 1.0
            if cleaned.contains("S") || cleaned.contains("LS") { multiplier = -1.0 }
            cleaned = cleaned.replacingOccurrences(of: "LS", with: "")
            cleaned = cleaned.replacingOccurrences(of: "LU", with: "")
            cleaned = cleaned.replacingOccurrences(of: "S", with: "")
            cleaned = cleaned.replacingOccurrences(of: "N", with: "")
            cleaned = cleaned.replacingOccurrences(of: "BT", with: "")
            cleaned = cleaned.replacingOccurrences(of: "BB", with: "")
            cleaned = cleaned.replacingOccurrences(of: "E", with: "")
            cleaned = cleaned.replacingOccurrences(of: "W", with: "")
            return Double(cleaned).map { $0 * multiplier }
        }

        guard let lat = parse(gempa.lintang), let lon = parse(gempa.bujur) else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = GempaViewModel()
    @State private var showList = false
    @State private var selectedMenu: GempaMenu = .terbaru
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let gempa = viewModel.gempaSingle {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: viewModel.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
                    )), annotationItems: [viewModel.coordinate]) { coordinate in
                        MapMarker(coordinate: coordinate)
                    }
                    .frame(height: 500)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Informasi Gempa")
                            .font(.headline)

                        Text("\(gempa.tanggal), \(gempa.jam), Magnitudo \(gempa.magnitude), Kedalaman \(gempa.kedalaman)")
                            .font(.subheadline)

                        Text("Wilayah: \(gempa.wilayah)")
                            .font(.subheadline)

                        if let potensi = gempa.potensi {
                            Text("Potensi: \(potensi)")
                                .font(.subheadline)
                        }
                        
                        if let dirasakan = gempa.dirasakan {
                            Text("Dirasakan: \(dirasakan)")
                                .font(.subheadline)
                        }
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 26))
                          

                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                } else {
                    ProgressView()
                        .onAppear {
                            viewModel.fetchGempaSingle()
                        }
                        .padding()
                }
            }
            .navigationTitle("Data Gempa BMKG")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Gempa Terbaru") {
                            dismiss()
                        }
                        Button("Gempa 5+ Magnitudo") {
                            selectedMenu = .magnitudo5
                            showList = true
                        }
                        Button("Gempa Dirasakan") {
                            selectedMenu = .dirasakan
                            showList = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                    }
                }
            }
            .background(
                NavigationLink(destination: ListGempaView(menu: selectedMenu), isActive: $showList) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

enum GempaMenu {
    case terbaru
    case magnitudo5
    case dirasakan
}

struct ListGempaView: View {
    let menu: GempaMenu
    @State private var dataGempa: [Gempa] = []
    @StateObject private var viewModel = GempaViewModel()

    var title: String {
        switch menu {
        case .terbaru: return "Gempa Terbaru"
        case .magnitudo5: return "Gempa 5+ Magnitudo"
        case .dirasakan: return "Gempa Dirasakan"
        }
    }

    var urlString: String {
        switch menu {
        case .terbaru:
            return "https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json"
        case .magnitudo5:
            return "https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json"
        case .dirasakan:
            return "https://data.bmkg.go.id/DataMKG/TEWS/gempadirasakan.json"
        }
    }

    var body: some View {
        List(dataGempa) { gempa in
            NavigationLink(destination: DetailMapView(gempa: gempa)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(gempa.tanggal) | \(gempa.jam)")
                        .font(.headline)
                    Text("Magnitude: \(gempa.magnitude), Kedalaman: \(gempa.kedalaman)")
                        .font(.subheadline)
                    Text("Wilayah: \(gempa.wilayah)")
                        .font(.subheadline)
                    if let potensi = gempa.potensi {
                        Text("Potensi: \(potensi)")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchGempaList(from: urlString) { gempas in
                self.dataGempa = gempas
            }
        }
    }
}

import SwiftUI
import MapKit

struct DetailMapView: View {
    let gempa: Gempa

    var coordinate: CLLocationCoordinate2D {
        func parse(_ string: String) -> Double? {
            var cleaned = string.replacingOccurrences(of: " ", with: "")
            var multiplier = 1.0
            if cleaned.contains("S") || cleaned.contains("LS") { multiplier = -1.0 }
            cleaned = cleaned.replacingOccurrences(of: "LS", with: "")
            cleaned = cleaned.replacingOccurrences(of: "LU", with: "")
            cleaned = cleaned.replacingOccurrences(of: "S", with: "")
            cleaned = cleaned.replacingOccurrences(of: "N", with: "")
            cleaned = cleaned.replacingOccurrences(of: "BT", with: "")
            cleaned = cleaned.replacingOccurrences(of: "BB", with: "")
            cleaned = cleaned.replacingOccurrences(of: "E", with: "")
            cleaned = cleaned.replacingOccurrences(of: "W", with: "")
            return Double(cleaned).map { $0 * multiplier }
        }

        guard let lat = parse(gempa.lintang), let lon = parse(gempa.bujur) else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
                )), annotationItems: [coordinate]) { coordinate in
                    MapMarker(coordinate: coordinate)
                }
                .frame(height: 500)
                .cornerRadius(12)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("Wilayah: \(gempa.wilayah)")
                            .font(.headline)
                        Text("Tanggal: \(gempa.tanggal)")
                        Text("Jam: \(gempa.jam)")
                        Text("Magnitude: \(gempa.magnitude)")
                        Text("Kedalaman: \(gempa.kedalaman)")
                        if let potensi = gempa.potensi {
                            Text("Potensi: \(potensi)")
                        }
                        if let dirasakan = gempa.dirasakan {
                            Text("Dirasakan: \(dirasakan)")
                        }
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 26))
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.top)
        }
        .navigationTitle("Detail Gempa")
        .navigationBarTitleDisplayMode(.inline)
    }
}


extension CLLocationCoordinate2D: Identifiable {
    public var id: String { "\(latitude),\(longitude)" }
}

