import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCountry: String?
    @Environment(\.dismiss) var dismiss
    var onSelection: () -> Void
    
    @State private var searchText = ""
    
    let countries = [
        "All Countries": nil,
        "Unknown": "Unknown",
        "United States": "United States",
        "United Kingdom": "United Kingdom",
        "Canada": "Canada",
        "Australia": "Australia",
        "Germany": "Germany",
        "France": "France",
        "Italy": "Italy",
        "Spain": "Spain",
        "Netherlands": "Netherlands",
        "Sweden": "Sweden",
        "Norway": "Norway",
        "Denmark": "Denmark",
        "Finland": "Finland",
        "Ireland": "Ireland",
        "Japan": "Japan",
        "South Korea": "South Korea",
        "China": "China",
        "New Zealand": "New Zealand",
        "Mexico": "Mexico",
        "Brazil": "Brazil",
        "Argentina": "Argentina",
        "South Africa": "South Africa",
        "India": "India",
        "Thailand": "Thailand",
        "Singapore": "Singapore",
        "Malaysia": "Malaysia",
        "Indonesia": "Indonesia",
        "Philippines": "Philippines",
        "Portugal": "Portugal",
        "Greece": "Greece",
        "Turkey": "Turkey",
        "Poland": "Poland",
        "Czech Republic": "Czech Republic",
        "Switzerland": "Switzerland",
        "Austria": "Austria",
        "Belgium": "Belgium",
    ]
    
    var filteredCountries: [(String, String?)] {
        let allCountries = countries.map { (key, value) in (key, value) }
        if searchText.isEmpty {
            return allCountries
        }
        return allCountries.filter { $0.0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries, id: \.0) { country, value in
                    Button {
                        selectedCountry = value
                        onSelection()
                        dismiss()
                    } label: {
                        HStack {
                            Text(country)
                                .foregroundColor(.white)
                            Spacer()
                            if selectedCountry == value || (selectedCountry == nil && value == nil) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search countries")
            .background(Color("Background"))
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CountryPickerView(selectedCountry: .constant(nil)) {
        // Preview
    }
    .preferredColorScheme(.dark)
}
