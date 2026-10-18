import Foundation
@testable import Told

enum Fixtures {
    static let durations: [String: Double] = ["technology": 19.49, "planet": 20.30, "science": 19.02, "culture": 19.56, "business": 21.26]
    static let source = NewsSource(id: "nasa", name: "NASA", title: "Science and discovery", url: URL(string: "https://science.nasa.gov/")!, note: "Explore science and discovery with NASA.")
    static let stories: [Story] = [
        story("technology", "The next wave of AI", .technology, "Smaller models are bringing more computation onto personal devices. That could mean faster responses and less data leaving a device, but performance still depends on the task, hardware, and model.", "technology", "https://www.nist.gov/artificial-intelligence", "NIST"),
        story("planet", "A different kind of energy reserve", .planet, "Storing energy is about more than batteries. Pumped water, heat, and other approaches can help match renewable electricity supply with demand. Each has different costs, locations, and trade-offs.", "planet", "https://www.iea.org/energy-system/electricity/energy-storage", "IEA"),
        story("science", "Listening to a changing ocean", .science, "Researchers use sound to understand the ocean. Listening can reveal patterns in marine life and human activity that are difficult to observe from the surface. Good measurements need careful context.", "technology", "https://oceanservice.noaa.gov/", "NOAA"),
        story("culture", "Why cities are making room to linger", .culture, "Public spaces shape how people experience a city. Shade, seating, and walkable routes can make daily life more comfortable. The strongest designs begin with the people who already use a place.", "daily", "https://www.unesco.org/en/cities", "UNESCO"),
        story("business", "The value of repairing what we own", .business, "Repair changes the economics of everyday products. Access to parts, useful instructions, and durable design can extend a product’s life. A repairable product is only useful if repair is practical and affordable.", "planet", "https://www.eea.europa.eu/en/topics/in-depth/circular-economy", "European Environment Agency")
    ]
    static func story(_ id: String, _ title: String, _ category: Interest, _ summary: String, _ artwork: String, _ url: String, _ publisher: String) -> Story {
        let transcript = "You’re listening to told. \(title). \(summary) Take a moment to explore the background, or ask a question whenever you’re curious."
        return Story(id: id, title: title, category: category, summary: summary, transcript: transcript, sources: [NewsSource(id: id, name: publisher, title: "Explore the background", url: URL(string: url)!, note: "Background reading from \(publisher).")], artworkID: artwork, audioResource: id, duration: durations[id] ?? 45)
    }
}
