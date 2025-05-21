import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Data Models
struct BusStop: Identifiable {
    let id: String
    let name: String
    let location: CLLocationCoordinate2D
}

struct BusRoute {
    let id: String
    let name: String
    let stops: [BusStop]
    let color: UIColor
    
    func polylineBetween(start: BusStop, end: BusStop) -> MKPolyline? {
        guard let startIdx = stops.firstIndex(where: { $0.id == start.id }),
              let endIdx = stops.firstIndex(where: { $0.id == end.id }) else { return nil }
        
        let coordinates: [CLLocationCoordinate2D]
        if startIdx <= endIdx {
            coordinates = stops[startIdx...endIdx].map { $0.location }
        } else {
            coordinates = stops[endIdx...startIdx].reversed().map { $0.location }
        }
        
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    func stopsBetween(start: BusStop, end: BusStop) -> [BusStop] {
        guard let startIdx = stops.firstIndex(where: { $0.id == start.id }),
              let endIdx = stops.firstIndex(where: { $0.id == end.id }) else { return [] }
        
        let range = startIdx < endIdx ? startIdx...endIdx : endIdx...startIdx
        return Array(stops[range])
    }
}

extension UIColor {
    static let route1 = UIColor(hex: "#A8DADC") // Soft teal
    static let route2 = UIColor(hex: "#F4A261") // Muted orange
    static let route3 = UIColor(hex: "#E9C46A") // Warm yellow
    static let route4 = UIColor(hex: "#9B5DE5") // Soft purple
    static let route5 = UIColor(hex: "#F28482") // Light coral
    static let route6 = UIColor(hex: "#6A994E") // Muted green
    static let route7 = UIColor(hex: "#FFB4A2") // Pastel peach
    static let route8 = UIColor(hex: "#B5E48C") // Light lime
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexFormatted.hasPrefix("#") {
            hexFormatted.removeFirst()
        }
        
        assert(hexFormatted.count == 6, "Invalid hex code.")
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}

struct RouteStep: Identifiable, Equatable {
    let id = UUID()
    let time: String
    let location: String
    let address: String?
    let duration: String?
    let transportType: TransportType
    let stops: [String]?
    let coordinate: CLLocationCoordinate2D?
    
    enum TransportType {
        case walk, bus, destination
    }
}

struct SuggestedRoute: Identifiable {
    let id = UUID()
    let route: BusRoute
    let startStop: BusStop
    let endStop: BusStop
    let walkingTimeToStart: TimeInterval
    let busTravelTime: TimeInterval
    let walkingTimeToDestination: TimeInterval
    let totalTime: TimeInterval
    let schedules: [String]
    
    var formattedTotalTime: String {
        let totalMinutes = Int(totalTime / 60)
        return "\(totalMinutes)"
    }

}

// MARK: - Route Planner
class RoutePlanner: NSObject, ObservableObject {
    @Published var routes: [MKPolyline] = []
    @Published var routeSteps: [RouteStep] = []
    @Published var suggestedRoutes: [SuggestedRoute] = []
    @Published var showBusStops: Bool = false
    @Published var showDrivingRoute: Bool = false
    @Published var drivingRoute: MKPolyline?
    @Published var visibleBusStops: [BusStop] = []
    @Published var currentRoute: BusRoute?
    @Published var currentRouteColor: Color = .gray
    
    public let bsdBusStops: [BusStop]
    public let bsdLinkRoutes: [BusRoute]
    
    override init() {
        // Initialize BSD Link stops
        self.bsdBusStops = [
            BusStop(id: "BS01", name: "Intermoda", location: CLLocationCoordinate2D(latitude: -6.319902912486388, longitude: 106.64371452384238)),
            BusStop(id: "BS02", name: "Cosmo", location: CLLocationCoordinate2D(latitude: -6.312098624472068, longitude: 106.64866097703134)),
            BusStop(id: "BS03", name: "Verdant View", location: CLLocationCoordinate2D(latitude: -6.3135382058171885, longitude: 106.64862335719445)),
            BusStop(id: "BS04", name: "Eternity", location: CLLocationCoordinate2D(latitude: -6.314804674128097, longitude: 106.64629166413174)),
            BusStop(id: "BS05", name: "Simplicity 2", location: CLLocationCoordinate2D(latitude: -6.313048540439234, longitude: 106.6425585810072)),
            BusStop(id: "BS06", name: "Edutown 1", location: CLLocationCoordinate2D(latitude: -6.3024419386956625, longitude: 106.64175422053961)),
            BusStop(id: "BS07", name: "Edutown 2", location: CLLocationCoordinate2D(latitude: -6.301401045958158, longitude: 106.64161410520205)),
            BusStop(id: "BS08", name: "ICE 1", location: CLLocationCoordinate2D(latitude: -6.297305991629695, longitude: 106.63663993540509)),
            BusStop(id: "BS09", name: "ICE 2", location: CLLocationCoordinate2D(latitude: -6.301798026906297, longitude: 106.63537576609392)),
            BusStop(id: "BS10", name: "ICE Business Park", location: CLLocationCoordinate2D(latitude: -6.303322716671507, longitude: 106.63447285075002)),
            BusStop(id: "BS11", name: "ICE 6", location: CLLocationCoordinate2D(latitude: -6.299214743448269, longitude: 106.63501661265211)),
            BusStop(id: "BS12", name: "ICE 5", location: CLLocationCoordinate2D(latitude: -6.296908022160658, longitude: 106.63614993540504)),
            BusStop(id: "BS13", name: "GOP 1", location: CLLocationCoordinate2D(latitude: -6.301333338511644, longitude: 106.6491341047173)),
            BusStop(id: "BS14", name: "SML Plaza", location: CLLocationCoordinate2D(latitude: -6.3018206829147045, longitude: 106.65107827402896)),
            BusStop(id: "BS15", name: "The Breeze", location: CLLocationCoordinate2D(latitude: -6.301369321397565, longitude: 106.65315717850528)),
            BusStop(id: "BS16", name: "CBD Timur 1", location: CLLocationCoordinate2D(latitude: -6.302837404339348, longitude: 106.65015285074993)),
            BusStop(id: "BS17", name: "CBD Timur 2", location: CLLocationCoordinate2D(latitude: -6.301030700563775, longitude: 106.64876966575737)),
            BusStop(id: "BS18", name: "GOP 2", location: CLLocationCoordinate2D(latitude: -6.301030700563775, longitude: 106.64876966575737)),
            BusStop(id: "BS19", name: "Nava Park 1", location: CLLocationCoordinate2D(latitude: -6.299573087873732, longitude: 106.64984707200264)),
            BusStop(id: "BS20", name: "SWA 2", location: CLLocationCoordinate2D(latitude: -6.299630155562472, longitude: 106.66243293720618)),
            BusStop(id: "BS21", name: "Giant", location: CLLocationCoordinate2D(latitude: -6.299347597253314, longitude: 106.6666351301771)),
            BusStop(id: "BS22", name: "Eka Hospital 1", location: CLLocationCoordinate2D(latitude: -6.299065485207059, longitude: 106.67031394722062)),
            BusStop(id: "BS23", name: "Puspita Loka", location: CLLocationCoordinate2D(latitude: -6.295377145696457, longitude: 106.67766489040433)),
            BusStop(id: "BS24", name: "Polsek Serpong", location: CLLocationCoordinate2D(latitude: -6.29603586772109, longitude: 106.68131227661276)),
            BusStop(id: "BS25", name: "Ruko Madrid", location: CLLocationCoordinate2D(latitude: -6.30196884684132, longitude: 106.6843857194694)),
            BusStop(id: "BS26", name: "Pasar Modern Timur", location: CLLocationCoordinate2D(latitude: -6.305348912751656, longitude: 106.68582347971999)),
            BusStop(id: "BS27", name: "Griya Loka 1", location: CLLocationCoordinate2D(latitude: -6.304835825560039, longitude: 106.68239886809873)),
            BusStop(id: "BS28", name: "Sektor 1.3", location: CLLocationCoordinate2D(latitude: -6.3057778200200305, longitude: 106.67991191028288)),
            BusStop(id: "BS29", name: "Griya Loka 2", location: CLLocationCoordinate2D(latitude: -6.304961931657671, longitude: 106.68151702006185)),
            BusStop(id: "BS30", name: "Santa Ursula 1", location: CLLocationCoordinate2D(latitude: -6.302771931151865, longitude: 106.6846528507499)),
            BusStop(id: "BS31", name: "Santa Ursula 2", location: CLLocationCoordinate2D(latitude: -6.300150681430886, longitude: 106.68316410471716)),
            BusStop(id: "BS32", name: "Sentra Onderdil", location: CLLocationCoordinate2D(latitude: -6.296683334763473, longitude: 106.6812441047167)),
            BusStop(id: "BS33", name: "Autopart", location: CLLocationCoordinate2D(latitude: -6.295531407562985, longitude: 106.67815419672414)),
            BusStop(id: "BS34", name: "Eka Hospital 2", location: CLLocationCoordinate2D(latitude: -6.299377523498342, longitude: 106.67009430185223)),
            BusStop(id: "BS35", name: "East Business District", location: CLLocationCoordinate2D(latitude: -6.299293336866941, longitude: 106.6669586814378)),
            BusStop(id: "BS36", name: "SWA 1", location: CLLocationCoordinate2D(latitude: -6.299345368339194, longitude: 106.6627761735028)),
            BusStop(id: "BS37", name: "Green Cove", location: CLLocationCoordinate2D(latitude: -6.2993814628841855, longitude: 106.65987993540543)),
            BusStop(id: "BS38", name: "AEON Mall 1", location: CLLocationCoordinate2D(latitude: -6.303120040327548, longitude: 106.64347755092595)),
            BusStop(id: "BS39", name: "CBD Barat 2", location: CLLocationCoordinate2D(latitude: -6.302221368040868, longitude: 106.64205317791004)),
            BusStop(id: "BS40", name: "Simplicity 1", location: CLLocationCoordinate2D(latitude: -6.312784863402183, longitude: 106.64423142592663)),
            BusStop(id: "BS41", name: "Greenwich Park Office", location: CLLocationCoordinate2D(latitude: -6.276622057947269, longitude: 106.63404)),
            BusStop(id: "BS42", name: "De Maja", location: CLLocationCoordinate2D(latitude: -6.280957532704141, longitude: 106.63961596488363)),
            BusStop(id: "BS43", name: "De Heliconia 2", location: CLLocationCoordinate2D(latitude: -6.283308041078943, longitude: 106.64115927116399)),
            BusStop(id: "BS44", name: "De Nara", location: CLLocationCoordinate2D(latitude: -6.285010028454532, longitude: 106.64400801314942)),
            BusStop(id: "BS45", name: "De Park 2", location: CLLocationCoordinate2D(latitude: -6.286975378906274, longitude: 106.64901655547753)),
            BusStop(id: "BS46", name: "Nava Park 2", location: CLLocationCoordinate2D(latitude: -6.290774052160064, longitude: 106.64982436896942)),
            BusStop(id: "BS47", name: "Giardina", location: CLLocationCoordinate2D(latitude: -6.291448715328519, longitude: 106.64828215809898)),
            BusStop(id: "BS48", name: "Collinare", location: CLLocationCoordinate2D(latitude: -6.2906680437956, longitude: 106.64538437301604)),
            BusStop(id: "BS49", name: "Foglio", location: CLLocationCoordinate2D(latitude: -6.293770702497992, longitude: 106.64307050539043)),
            BusStop(id: "BS50", name: "Studento 2", location: CLLocationCoordinate2D(latitude: -6.295336698270585, longitude: 106.642156093254)),
            BusStop(id: "BS51", name: "Albera", location: CLLocationCoordinate2D(latitude: -6.296627753866824, longitude: 106.64468911954826)),
            BusStop(id: "BS52", name: "Foresta 1", location: CLLocationCoordinate2D(latitude: -6.296720702463259, longitude: 106.647792186508)),
            BusStop(id: "BS53", name: "Simpang Foresta", location: CLLocationCoordinate2D(latitude: -6.299027376515015, longitude: 106.6479729112976)),
            BusStop(id: "BS54", name: "Allevare", location: CLLocationCoordinate2D(latitude: -6.297092109712094, longitude: 106.64701553315535)),
            BusStop(id: "BS55", name: "Fiore", location: CLLocationCoordinate2D(latitude: -6.296699551490208, longitude: 106.64459637983225)),
            BusStop(id: "BS56", name: "Studento 1", location: CLLocationCoordinate2D(latitude: -6.29562483743795, longitude: 106.64207466523365)),
            BusStop(id: "BS57", name: "Naturale", location: CLLocationCoordinate2D(latitude: -6.293753267157416, longitude: 106.64283525450247)),
            BusStop(id: "BS58", name: "Fresco", location: CLLocationCoordinate2D(latitude: -6.290917364823557, longitude: 106.64513283298477)),
            BusStop(id: "BS59", name: "Primavera", location: CLLocationCoordinate2D(latitude: -6.291167379758763, longitude: 106.64836291534402)),
            BusStop(id: "BS60", name: "Foresta 2", location: CLLocationCoordinate2D(latitude: -6.290166708825742, longitude: 106.64961926711759)),
            BusStop(id: "BS61", name: "FBL 5", location: CLLocationCoordinate2D(latitude: -6.28803670795394, longitude: 106.64433874198559)),
            BusStop(id: "BS62", name: "Courts Mega Store", location: CLLocationCoordinate2D(latitude: -6.286230035126002, longitude: 106.63887072883601)),
            BusStop(id: "BS63", name: "Q BIG 1", location: CLLocationCoordinate2D(latitude: -6.284470858067212, longitude: 106.63834676447388)),
            BusStop(id: "BS64", name: "Lulu", location: CLLocationCoordinate2D(latitude: -6.2806509823429675, longitude: 106.6363809368485)),
            BusStop(id: "BS65", name: "Greenwich Park 1", location: CLLocationCoordinate2D(latitude: -6.27722670353427, longitude: 106.63519582664144)),
            BusStop(id: "BS66", name: "Prestigia", location: CLLocationCoordinate2D(latitude: -6.294574704864883, longitude: 106.63434147612814)),
            BusStop(id: "BS67", name: "The Mozia 1", location: CLLocationCoordinate2D(latitude: -6.291653845052858, longitude: 106.62850019474901)),
            BusStop(id: "BS68", name: "Vanya Park", location: CLLocationCoordinate2D(latitude: -6.295320322717712, longitude: 106.62186825923906)),
            BusStop(id: "BS69", name: "Piazza Mozia", location: CLLocationCoordinate2D(latitude: -6.290512106223089, longitude: 106.62767242455752)),
            BusStop(id: "BS70", name: "The Mozia 2", location: CLLocationCoordinate2D(latitude: -6.291595339802968, longitude: 106.62865576632026)),
            BusStop(id: "BS71", name: "Illustria", location: CLLocationCoordinate2D(latitude: -6.294029293630429, longitude: 106.63433876241467)),
            BusStop(id: "BS72", name: "CBD Barat 2", location: CLLocationCoordinate2D(latitude: -6.3023066800188365, longitude: 106.64210145762934)),
            BusStop(id: "BS73", name: "Lobby AEON Mall", location: CLLocationCoordinate2D(latitude: -6.303683149161957, longitude: 106.64356012276883)),
            BusStop(id: "BS74", name: "CBD Utara 3", location: CLLocationCoordinate2D(latitude: -6.2987607030499175, longitude: 106.6433604073996)),
            BusStop(id: "BS75", name: "CBD Barat 1", location: CLLocationCoordinate2D(latitude: -6.299449375144083, longitude: 106.64191227244648)),
            BusStop(id: "BS76", name: "AEON Mall 2", location: CLLocationCoordinate2D(latitude: -6.302851368209015, longitude: 106.64431300128254)),
            BusStop(id: "BS77", name: "Froogy", location: CLLocationCoordinate2D(latitude: -6.29724016790295, longitude: 106.64050719580258)),
            BusStop(id: "BS78", name: "Gramedia", location: CLLocationCoordinate2D(latitude: -6.291269859841771, longitude: 106.6394645156416)),
            BusStop(id: "BS79", name: "Icon Centro", location: CLLocationCoordinate2D(latitude: -6.314595375739716, longitude: 106.646253224144)),
            BusStop(id: "BS80", name: "Horizon Broadway", location: CLLocationCoordinate2D(latitude: -6.313141392686883, longitude: 106.6503970845614)),
            BusStop(id: "BS81", name: "BSD Extreme Park", location: CLLocationCoordinate2D(latitude: -6.30975136988534, longitude: 106.6537962107912)),
            BusStop(id: "BS82", name: "Saveria", location: CLLocationCoordinate2D(latitude: -6.307346701354917, longitude: 106.65359854223301))
        ]
        
        // Initialize BSD Link routes
        self.bsdLinkRoutes = [
            BusRoute(id: "R01", name: "Intermoda - Sektor 1.3", stops: [bsdBusStops[0], bsdBusStops[4], bsdBusStops[5], bsdBusStops[6], bsdBusStops[12], bsdBusStops[13], bsdBusStops[14], bsdBusStops[15], bsdBusStops[16], bsdBusStops[18], bsdBusStops[21], bsdBusStops[22], bsdBusStops[23], bsdBusStops[24], bsdBusStops[25], bsdBusStops[26], bsdBusStops[27]], color: .route1),
            BusRoute(id: "R02", name: "Sektor 1.3 - Intermoda", stops: [bsdBusStops[27], bsdBusStops[28], bsdBusStops[29], bsdBusStops[30], bsdBusStops[31], bsdBusStops[32], bsdBusStops[33], bsdBusStops[34], bsdBusStops[35], bsdBusStops[14], bsdBusStops[15], bsdBusStops[16], bsdBusStops[39], bsdBusStops[0]], color: .route2),
            BusRoute(id: "R03", name: "Greenwich Park - Sektor 1.3", stops: [bsdBusStops[40], bsdBusStops[41], bsdBusStops[42], bsdBusStops[43], bsdBusStops[44], bsdBusStops[46], bsdBusStops[47], bsdBusStops[48], bsdBusStops[49], bsdBusStops[50], bsdBusStops[51], bsdBusStops[12], bsdBusStops[13], bsdBusStops[14], bsdBusStops[15], bsdBusStops[16], bsdBusStops[18], bsdBusStops[21], bsdBusStops[22], bsdBusStops[25], bsdBusStops[26], bsdBusStops[27]], color: .route3),
            BusRoute(id: "R04", name: "Sektor 1.3 - Greenwich Park", stops: [bsdBusStops[27], bsdBusStops[28], bsdBusStops[29], bsdBusStops[30], bsdBusStops[31], bsdBusStops[32], bsdBusStops[33], bsdBusStops[34], bsdBusStops[35], bsdBusStops[14], bsdBusStops[15], bsdBusStops[16], bsdBusStops[52], bsdBusStops[53], bsdBusStops[54], bsdBusStops[55], bsdBusStops[56], bsdBusStops[57], bsdBusStops[58], bsdBusStops[61], bsdBusStops[62], bsdBusStops[63], bsdBusStops[64], bsdBusStops[40]], color: .route4),
            BusRoute(id: "R05", name: "Intermoda - De Park (Rute 1)", stops: [bsdBusStops[0], bsdBusStops[4], bsdBusStops[5], bsdBusStops[6], bsdBusStops[7], bsdBusStops[11], bsdBusStops[76], bsdBusStops[77], bsdBusStops[61], bsdBusStops[62], bsdBusStops[63], bsdBusStops[64], bsdBusStops[40], bsdBusStops[41], bsdBusStops[42], bsdBusStops[43], bsdBusStops[44]], color: .route5),
            BusRoute(id: "R06", name: "Intermoda - De Park (Rute 2)", stops: [bsdBusStops[0], bsdBusStops[78], bsdBusStops[79], bsdBusStops[80], bsdBusStops[81], bsdBusStops[13], bsdBusStops[14], bsdBusStops[15], bsdBusStops[37], bsdBusStops[75], bsdBusStops[16], bsdBusStops[52], bsdBusStops[53], bsdBusStops[54], bsdBusStops[55], bsdBusStops[56], bsdBusStops[57], bsdBusStops[58], bsdBusStops[59], bsdBusStops[44]], color: .route6),
            BusRoute(id: "R07", name: "The Breeze - AEON - ICE - The Breeze", stops: [bsdBusStops[14], bsdBusStops[15], bsdBusStops[16], bsdBusStops[73], bsdBusStops[74], bsdBusStops[71], bsdBusStops[37], bsdBusStops[75], bsdBusStops[73], bsdBusStops[9], bsdBusStops[11], bsdBusStops[74], bsdBusStops[71], bsdBusStops[37], bsdBusStops[75], bsdBusStops[16], bsdBusStops[18], bsdBusStops[36], bsdBusStops[14]], color: .route7),
            BusRoute(id: "R08", name: "Intermoda - Vanya Park - Intermoda", stops: [bsdBusStops[0], bsdBusStops[2], bsdBusStops[3], bsdBusStops[4], bsdBusStops[47], bsdBusStops[48], bsdBusStops[49], bsdBusStops[50], bsdBusStops[66], bsdBusStops[44], bsdBusStops[45], bsdBusStops[46], bsdBusStops[67], bsdBusStops[68], bsdBusStops[69], bsdBusStops[70], bsdBusStops[71], bsdBusStops[5], bsdBusStops[6], bsdBusStops[7], bsdBusStops[72], bsdBusStops[73], bsdBusStops[54], bsdBusStops[74], bsdBusStops[8], bsdBusStops[55], bsdBusStops[56], bsdBusStops[60], bsdBusStops[61], bsdBusStops[62], bsdBusStops[1], bsdBusStops[0]], color: .route8)
        ]
        
        super.init()
    }
    func colorForRoute(_ route: BusRoute) -> Color {
        return Color(route.color)
    }
    
    func findNearbyStops(to coordinate: CLLocationCoordinate2D, maxDistance: Double = 500) -> [BusStop] {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return bsdBusStops.filter { stop in
            let stopLocation = CLLocation(latitude: stop.location.latitude, longitude: stop.location.longitude)
            let distance = stopLocation.distance(from: userLocation)
            return distance <= maxDistance
        }
    }
    
    func findRouteOptions(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        suggestedRoutes.removeAll()
        showBusStops = false
        showDrivingRoute = true
        visibleBusStops = []
        
        // Get driving route for overview
        getDrivingRoute(from: start, to: end) { polyline in
            DispatchQueue.main.async {
                self.drivingRoute = polyline
            }
        }
        
        let startStops = findNearbyStops(to: start)
        let endStops = findNearbyStops(to: end)
        
        var routeCandidates: [SuggestedRoute] = []
        
        for startStop in startStops {
            for endStop in endStops {
                // Filter routes that contain both stops AND allow the direction
                let validRoutes = bsdLinkRoutes.filter { route in
                    guard let startIndex = route.stops.firstIndex(where: { $0.id == startStop.id }),
                          let endIndex = route.stops.firstIndex(where: { $0.id == endStop.id })
                    else { return false }
                    
                    // Only allow routes where start comes BEFORE end (one-way)
                    return startIndex <= endIndex
                }
                
                for route in validRoutes {
                    guard let startIndex = route.stops.firstIndex(where: { $0.id == startStop.id }),
                          let endIndex = route.stops.firstIndex(where: { $0.id == endStop.id })
                    else { continue }
                    
                    let walkingTimeToStart = calculateWalkingTime(from: start, to: startStop.location)
                    let stopCount = endIndex - startIndex // No abs() since direction is enforced
                    let busTravelTime = TimeInterval(stopCount * 3 * 60)
                    let walkingTimeToDestination = calculateWalkingTime(from: endStop.location, to: end)
                    let totalTime = walkingTimeToStart + busTravelTime + walkingTimeToDestination
                    
                    // Generate schedules
                    let schedules: [String] = {
                        var times = [String]()

                        for hour in 14..<16 {
                                times.append(String(format: "%02d:17", hour))
                                times.append(String(format: "%02d:37", hour))
                                times.append(String(format: "%02d:57", hour))
                            }
                        for hour in 16..<19 {
                                times.append(String(format: "%02d:04", hour))
                                times.append(String(format: "%02d:24", hour))
                                times.append(String(format: "%02d:54", hour))
                                times.append(String(format: "%02d:59", hour))
                            }
                        for hour in 19..<20 {
                                times.append(String(format: "%02d:10", hour))
                                times.append(String(format: "%02d:30", hour))
                            }
                            
                            return times
                    }()
                    
                    let suggestedRoute = SuggestedRoute(
                        route: route,
                        startStop: startStop,
                        endStop: endStop,
                        walkingTimeToStart: walkingTimeToStart,
                        busTravelTime: busTravelTime,
                        walkingTimeToDestination: walkingTimeToDestination,
                        totalTime: totalTime,
                        schedules: schedules
                    )
                    
                    routeCandidates.append(suggestedRoute)
                }
            }
        }
        
        var bestRoutesPerID: [String: SuggestedRoute] = [:]
            for candidate in routeCandidates {
                if let existing = bestRoutesPerID[candidate.route.id] {
                    if candidate.totalTime < existing.totalTime {
                        bestRoutesPerID[candidate.route.id] = candidate
                    }
                } else {
                    bestRoutesPerID[candidate.route.id] = candidate
                }
            }
        
        let sortedRoutes = bestRoutesPerID.values.sorted { $0.totalTime < $1.totalTime }
        suggestedRoutes = Array(sortedRoutes.prefix(3))
        
        // Optional: Show warning if no routes found
        if suggestedRoutes.isEmpty {
            print("No valid routes found. Try different start/end points.")
        }
    }
    
    func planSpecificRoute(_ suggestedRoute: SuggestedRoute,
                         from start: CLLocationCoordinate2D,
                         to end: CLLocationCoordinate2D,
                         startName: String,
                         endName: String) {
        currentRoute = suggestedRoute.route
        currentRouteColor = Color(suggestedRoute.route.color)
        routes.removeAll()
        routeSteps.removeAll()
        showBusStops = true
        showDrivingRoute = false
        
        let relevantStops = suggestedRoute.route.stopsBetween(start: suggestedRoute.startStop,
                                                            end: suggestedRoute.endStop)
        visibleBusStops = relevantStops
        
        Task {
                    let busPolylines = await getDrivingRoutesBetweenStops(relevantStops)
                    DispatchQueue.main.async {
                        self.routes.append(contentsOf: busPolylines)
                    }
                }
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        let now = Date()
        var accumulatedTime: TimeInterval = 0
        
        // Start Step with real name
        let startStep = RouteStep(
            time: dateFormatter.string(from: now),
            location: startName,
            address: nil,
            duration: nil,
            transportType: .walk,
            stops: nil,
            coordinate: start
        )
        routeSteps.append(startStep)
        
        getWalkingRoute(from: start, to: suggestedRoute.startStop.location) { walkRoute in
            DispatchQueue.main.async {
                self.routes.append(walkRoute.polyline)
                
                let walkStep = RouteStep(
                    time: dateFormatter.string(from: Calendar.current.date(byAdding: .second,
                                                                          value: Int(accumulatedTime),                           to: now)!),
                    location: "Walk to \(suggestedRoute.startStop.name)",
                    address: nil,
                    duration: self.formattedDuration(suggestedRoute.walkingTimeToStart),
                    transportType: .walk,
                    stops: nil,
                    coordinate: suggestedRoute.startStop.location
                )
                self.routeSteps.append(walkStep)
                accumulatedTime += suggestedRoute.walkingTimeToStart
                
                // Add individual bus stop steps
                let stopsPerMinute = Double(relevantStops.count) / (suggestedRoute.busTravelTime / 60)
                var currentBusTime = accumulatedTime
                
                for stop in relevantStops {
                    let step = RouteStep(
                        time: dateFormatter.string(from: Calendar.current.date(byAdding: .second,
                                                                              value: Int(currentBusTime),
                                                                              to: now)!),
                        location: stop.name,
                        address: "\(suggestedRoute.route.name)",
                        duration: nil,
                        transportType: .bus,
                        stops: nil,
                        coordinate: stop.location
                    )
                    self.routeSteps.append(step)
                    currentBusTime += (60 / stopsPerMinute) // Add time between stops
                }
                
                accumulatedTime += suggestedRoute.busTravelTime
                
                self.getWalkingRoute(from: suggestedRoute.endStop.location, to: end) { finalWalk in
                    DispatchQueue.main.async {
                        self.routes.append(finalWalk.polyline)
                        
                        let finalStep = RouteStep(
                            time: dateFormatter.string(from: Calendar.current.date(byAdding: .second,
                                                                                  value: Int(accumulatedTime),
                                                                                  to: now)!),
                            location: "Walk to Destination",
                            address: nil,
                            duration: self.formattedDuration(suggestedRoute.walkingTimeToDestination),
                            transportType: .walk,
                            stops: nil,
                            coordinate: end
                        )
                        self.routeSteps.append(finalStep)
                        accumulatedTime += suggestedRoute.walkingTimeToDestination
                        
                        // Destination Step with real name
                        let destinationStep = RouteStep(
                            time: dateFormatter.string(from: Calendar.current.date(byAdding: .second,
                                                                                 value: Int(accumulatedTime),
                                                                                 to: now)!),
                            location: endName,
                            address: nil,
                            duration: nil,
                            transportType: .destination,
                            stops: nil,
                            coordinate: end
                        )
                        self.routeSteps.append(destinationStep)
                    }
                }
            }
        }
    }
    
    func clearRouteDetails() {
        routes.removeAll()
        routeSteps.removeAll()
        showBusStops = false
        visibleBusStops = []
    }
    
    private func getDrivingRoutesBetweenStops(_ stops: [BusStop]) async -> [MKPolyline] {
        var polylines: [MKPolyline] = []
        
        for i in 0..<stops.count-1 {
            let start = stops[i].location
            let end = stops[i+1].location
            
            do {
                let polyline = try await getDrivingPolyline(from: start, to: end)
                polylines.append(polyline)
            } catch {
                // Fallback to straight line if routing fails
                let coordinates = [start, end]
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polylines.append(polyline)
            }
        }
        
        return polylines
    }
    
    private func getDrivingPolyline(from start: CLLocationCoordinate2D,
                                      to end: CLLocationCoordinate2D) async throws -> MKPolyline {
            return try await withCheckedThrowingContinuation { continuation in
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
                request.transportType = .automobile
                
                MKDirections(request: request).calculate { response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let route = response?.routes.first {
                        continuation.resume(returning: route.polyline)
                    } else {
                        continuation.resume(throwing: NSError(domain: "RoutingError", code: 0))
                    }
                }
            }
        }
    
    private func calculateWalkingTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> TimeInterval {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distance = fromLocation.distance(from: toLocation)
        return (distance / 80) * 60
    }
    
    private func getDrivingRoute(from: CLLocationCoordinate2D,
                              to: CLLocationCoordinate2D,
                              completion: @escaping (MKPolyline) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        
        MKDirections(request: request).calculate { response, error in
            if let route = response?.routes.first {
                completion(route.polyline)
            } else {
                let coordinates = [from, to]
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                completion(polyline)
            }
        }
    }
    
    private func getWalkingRoute(from: CLLocationCoordinate2D,
                               to: CLLocationCoordinate2D,
                               completion: @escaping (MKRoute) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        
        MKDirections(request: request).calculate { response, _ in
            if let route = response?.routes.first {
                completion(route)
            }
        }
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: seconds) ?? ""
    }
}

// --- LocationManager remains the same ---
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with error: \(error.localizedDescription)")
    }
}

struct RouteStepsView: View {
    let steps: [RouteStep]
    let boardTime: String
    let etaTime: String
    let totalTime: String
    @Binding var currentDetent: PresentationDetent
    @Binding var showingRouteSteps: Bool
    @ObservedObject var routePlanner: RoutePlanner
    
    private var filteredSteps: [RouteStep] {
        steps.filter { step in
            !step.location.lowercased().hasPrefix("walk to")
        }
    }
    
    private func calculateStepTimes() -> [String] {
        guard !filteredSteps.isEmpty else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        guard let baseDate = dateFormatter.date(from: boardTime) else { return [] }
        
        var stepTimes: [String] = [boardTime] // Start with board time
        
        // Calculate time intervals between steps
        for i in 0..<filteredSteps.count-1 {
            let currentStep = filteredSteps[i]
            let nextStep = filteredSteps[i+1]
            
            // Calculate time interval based on distance and transport type
            let interval: TimeInterval
            if currentStep.transportType == .bus {
                // For bus, use fixed interval (e.g., 3 minutes per stop)
                interval = 3 * 60
            } else {
                // For walking, calculate based on distance
                let distance = CLLocation(latitude: currentStep.coordinate?.latitude ?? 0,
                                        longitude: currentStep.coordinate?.longitude ?? 0)
                    .distance(from: CLLocation(latitude: nextStep.coordinate?.latitude ?? 0,
                                             longitude: nextStep.coordinate?.longitude ?? 0))
                // Walking speed: 80 meters per minute
                interval = (distance / 80) * 60
            }
            
            let newTime = Calendar.current.date(byAdding: .second, value: Int(interval), to: baseDate)!
            stepTimes.append(dateFormatter.string(from: newTime))
        }
        
        return stepTimes
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header with close button
            HStack {
                Text("Route Detail")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    showingRouteSteps = false
                    currentDetent = .height(300)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .padding(.top, 20)
            
            // Time Summary
            HStack {
                HStack(alignment: .lastTextBaseline) {
                    Text("board on")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.3))
                    Text(boardTime)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.leading, -6)
                }
                
                Spacer().frame(width: 20)
                
                HStack(alignment: .lastTextBaseline) {
                    Text("ETA")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.3))
                    Text(etaTime)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.leading, -7)
                }
                Spacer()
                
                HStack(alignment: .lastTextBaseline) {
                    Text("est")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: 0x467F8E).opacity(0.8))
                    Text(totalTime)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Color(hex: 0x467F8E).opacity(0.9))
                        .padding(.leading, -6)
                    Text("min")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0x467F8E).opacity(0.8))
                        .padding(.leading, -8)
                }
                .padding(.top, -8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom)
            
            // Steps List
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    let stepTimes = calculateStepTimes()
                    
                    ForEach(Array(filteredSteps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 8) {
                            // Time and Location in pill shape
                            HStack(alignment: .top) {
                                Text(index < stepTimes.count ? stepTimes[index] : "--:--")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(Color(hex: 0x467F8E).opacity(0.8))
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.top, 6)
                                
                                Text(step.location)
                                    .foregroundColor(.black.opacity(0.7))
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 270, height: 44)
                                    .background(
                                        Capsule()
                                            .fill(.white)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 0)
                                    .fixedSize()
                            }
                            
                            // Transport details - show connection to next step
                            if index < filteredSteps.count - 1 {
                                let nextStep = filteredSteps[index + 1]
                                if let originalStepIndex = steps.firstIndex(where: { $0.id == step.id }),
                                   originalStepIndex + 1 < steps.count {
                                    let connectingStep = steps[originalStepIndex + 1]
                                    
                                    HStack(alignment: .top, spacing: 8) {
                                        // Transport name and icon
                                        HStack(spacing: 4) {
                                            Text(connectingStep.transportType == .walk ? "Walk" :
                                                 (connectingStep.address ?? "BSD Link Route"))
                                                .font(.system(size: 12, weight: .medium))
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.black.opacity(0.8))
                                                .padding(.horizontal, connectingStep.transportType == .bus ? 14 : 0)
                                                .padding(.vertical, connectingStep.transportType == .bus ? 6 : 0)
                                                .background(
                                                    connectingStep.transportType == .bus ?
                                                    Capsule()
                                                        .fill(routePlanner.currentRouteColor) : nil
                                                )
                                            Image(systemName: connectingStep.transportType == .walk ? "figure.walk" : "bus.fill")
                                                .foregroundColor(.black.opacity(0.8))
                                        }
                                        .frame(width: 190, height: 80, alignment: .trailing)
                                        
                                        // Line
                                        if connectingStep.transportType == .walk {
                                            DottedLine()
                                                .stroke(
                                                    style: StrokeStyle(
                                                        lineWidth: 6,
                                                        lineCap: .round,
                                                        dash: [7, 10]
                                                    )
                                                )
                                                .foregroundColor(.black.opacity(0.8))
                                                .frame(width: 6, height: 80)
                                        } else {
                                            Rectangle()
                                                .fill(routePlanner.currentRouteColor)
                                                .frame(width: 6, height: 80)
                                                .cornerRadius(10)
                                        }
                                        
                                        // Distance and time
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(distanceBetween(step.coordinate, nextStep.coordinate))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.black.opacity(0.8))
                                            
                                            Text(estimatedTime(step.coordinate, nextStep.coordinate, transportType: connectingStep.transportType))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.black.opacity(0.8))
                                        }
                                        .frame(width: 120, height: 80, alignment: .leading)
                                    }
                                    .padding(.leading, 24)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 1)
            }
            .padding(.bottom, 30)
        }
    }
    
    private func distanceBetween(_ coord1: CLLocationCoordinate2D?, _ coord2: CLLocationCoordinate2D?) -> String {
        guard let coord1 = coord1, let coord2 = coord2 else { return "N/A" }
        let distance = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            .distance(from: CLLocation(latitude: coord2.latitude, longitude: coord2.longitude))
        
        return distance < 1000 ?
            String(format: "%.0f m", distance) :
            String(format: "%.1f km", distance/1000)
    }
    
    private func estimatedTime(_ coord1: CLLocationCoordinate2D?, _ coord2: CLLocationCoordinate2D?, transportType: RouteStep.TransportType) -> String {
        guard let coord1 = coord1, let coord2 = coord2 else { return "N/A" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .short

        if transportType == .bus {
            let randomMinutes = Int.random(in: 2...3)
            return formatter.string(from: TimeInterval(randomMinutes * 60)) ?? "N/A"
        } else {
            let startLocation = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let endLocation = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            let distance = startLocation.distance(from: endLocation)

            let walkingSpeed: Double = 1.4 // meters per second
            let timeInterval = distance / walkingSpeed

            return formatter.string(from: timeInterval) ?? "N/A"
        }
    }
}

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Draw a vertical line from top to bottom
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

struct ContentView: View {
    @StateObject private var routePlanner = RoutePlanner()
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var initialRegionSet = false

    // Current Location Search
    @State private var currentLocationText: String = ""
    @State private var geocodedCurrentLocationText: String = ""
    @State private var currentLocationResults: [MKMapItem] = []
    @State private var currentLocationSearchTask: Task<Void, Never>?
    @FocusState private var isCurrentLocationFieldFocused: Bool
    @State private var isCurrentLocationFromDevice: Bool = true
    @State private var selectedCurrentLocationItem: MKMapItem?

    // Destination Search
    @State private var destinationText: String = ""
    @State private var destinationResults: [MKMapItem] = []
    @State private var destinationSearchTask: Task<Void, Never>?
    @FocusState private var isDestinationFieldFocused: Bool
    @State private var selectedDestinationItem: MKMapItem?
    
    @Namespace var mapScope
    
    @State private var isDetailSheetPresented = false
    @State private var currentDetent: PresentationDetent = .height(150)
    
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var showRouteError = false

    let bsdCityCoordinate = CLLocationCoordinate2D(latitude: -6.3024, longitude: 106.6522)
    
    var defaultMapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: bsdCityCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    let userLocationZoomSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    
    var tangerangSearchRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: bsdCityCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )
    }

    // Static constant for Tangerang localities to help the compiler
    private static let tangerangSpecificLocalities = ["Serpong", "Ciputat", "Pamulang", "Pondok Aren", "Karawaci", "Ciledug", "BSD", "Bintaro Sektor"]

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, scope:mapScope) {
                UserAnnotation()
                // Only show marker for selected destination, not all search results
                if let selectedDestination = selectedDestinationItem {
                    Marker(selectedDestination.name ?? "Destination", coordinate: selectedDestination.placemark.coordinate)
                }
                // Draw routes
                ForEach(routePlanner.routes, id: \.self) { route in
                    MapPolyline(route)
                            .stroke(Color.black, lineWidth: 11)
                    MapPolyline(route)
                        .stroke(routePlanner.currentRouteColor, lineWidth: 10) // Increased from 5
                }
                
                // Show bus stops
                ForEach(routePlanner.visibleBusStops) { stop in
                    Annotation(stop.name, coordinate: stop.location) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 6)) // Smaller size
                            .padding(4) // Less padding
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .clipShape(Circle()) // Circular shape
                    }
                }
                
                // Show markers
                if let start = startCoordinate {
                    Marker("Start", systemImage: "location.fill", coordinate: start)
                        .tint(.blue)
                }
                if let end = endCoordinate {
                    Marker("End", systemImage: "mappin.and.ellipse", coordinate: end)
                        .tint(.red)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 12) {
                    MapUserLocationButton(scope: mapScope)
                    MapPitchToggle(scope: mapScope)
                        .mapControlVisibility(.visible)
                    MapCompass(scope: mapScope)
                        .mapControlVisibility(.visible)
                }
                .padding(.trailing, 20)
                .padding(.bottom, bottomPaddingForControls)      // ← reactive bottom padding
                .animation(.easeInOut, value: currentDetent)
                .buttonBorderShape(.circle)
            }

            .mapScope(mapScope)
            .onAppear {
                locationManager.requestAuthorization()
            }
            .onChange(of: locationManager.authorizationStatus) { newStatus, _ in
                handleAuthorizationChange(status: newStatus)
            }
            .onReceive(locationManager.$userLocation) { location in
                guard let validLocation = location else { return }

                // 1️⃣ Only do your “first‑time” centering here:
                if !initialRegionSet,
                   (locationManager.authorizationStatus == .authorizedWhenInUse
                    || locationManager.authorizationStatus == .authorizedAlways)
                {
                    cameraPosition = .region(
                        MKCoordinateRegion(center: validLocation.coordinate,
                                           span: userLocationZoomSpan)
                    )
                    initialRegionSet = true
                }

                // 2️⃣ Then trigger the reverse‑geocode, but DON’T yet create the MKMapItem:
                if isCurrentLocationFromDevice {
                    reverseGeocode(location: validLocation)
                }
            }

            // Modified search interface structure
            VStack(spacing: 0) {
                // Use ZStack to position search fields and recommendations
                ZStack(alignment: .top) {
                    // Main layout
                    VStack(spacing: 10) {
                        // First search field
                        currentLocationSearchField
                            .padding(.horizontal)
                        
                        // Destination search field (no spacing adjustment for recommendations)
                        destinationSearchField
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Swap button positioned between the two fields
                    VStack {
                        Spacer().frame(height: 44) // Position it between the two fields
                        
                        Button(action: swapLocations) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.teal))
                        }
                        .offset(x: UIScreen.main.bounds.width / 2 - 55, y: 4) // Position on right side
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 0)
                    }
                    
                    // Current location recommendations positioned right under the first field
                    VStack {
                        Spacer().frame(height: 70) // Height of the current location search field + padding

                        if isCurrentLocationFieldFocused,
                           !currentLocationResults.isEmpty,
                           !currentLocationText.isEmpty
                        {
                            // 1. ScrollView instead of List
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(currentLocationResults, id: \.self) { item in
                                        Button(action: { selectCurrentLocation(item: item) }) {
                                            suggestionRow(for: item)
                                                .padding(.vertical, 12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // Remove default button chrome
                                    }
                                }
                            }
                            .frame(maxHeight: 300)    // cap it if you want a scrollable area
                            .background(Color.white)  // container color
                            .cornerRadius(20)         // true rounded rectangle
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
                            .padding(.horizontal)     // inset from screen edges
                            .zIndex(1)                // keep it above everything else
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    
                    // Destination recommendations positioned below destination field
                    VStack {
                        Spacer().frame(height: 124) // Combined height of both fields + padding

                        if isDestinationFieldFocused,
                           !destinationResults.isEmpty,
                           !destinationText.isEmpty
                        {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(destinationResults, id: \.self) { item in
                                        Button(action: { selectDestination(item: item) }) {
                                            suggestionRow(for: item)
                                                .padding(.vertical, 12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .frame(maxHeight: 300)    // cap scroll area if you like
                            .background(Color.white)  // container color
                            .cornerRadius(20)         // true rounded corners
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
                            .padding(.horizontal)     // inset from the edges
                            .zIndex(1)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                }
                
                Spacer()
            }
            
            
            .sheet(isPresented: $isDetailSheetPresented) {
                DetailBottomSheetView(
                    mapItem: selectedDestinationItem!,
                    isPresented: $isDetailSheetPresented,
                    routePlanner: routePlanner,
                    startCoordinate: startCoordinate,
                    endCoordinate: endCoordinate,
                    currentDetent: $currentDetent,
                    selectedCurrentLocationItem: $selectedCurrentLocationItem,
                    selectedDestinationItem: $selectedDestinationItem
                )
                .presentationDetents(
                    [.height(300), .height(500), .large],
                    selection: $currentDetent
                )
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(30)
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .onChange(of: isDetailSheetPresented) {
                if isDetailSheetPresented {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        currentDetent = .height(300)
                    }
                }
            }

        }
        .onChange(of: isCurrentLocationFieldFocused) { _, isFocused in
            if isFocused {
                if isCurrentLocationFromDevice { currentLocationText = "" }
            } else {
                if currentLocationText.isEmpty && !geocodedCurrentLocationText.isEmpty {
                    currentLocationText = geocodedCurrentLocationText
                    isCurrentLocationFromDevice = true
                }
                 if currentLocationText.isEmpty { currentLocationResults = [] }
            }
        }
        .onChange(of: isDestinationFieldFocused) { _, isFocused in
            if !isFocused && destinationText.isEmpty { destinationResults = [] }
        }
        .onChange(of: selectedCurrentLocationItem) { _, newValue in
            updateCoordinates()
        }
        .onChange(of: selectedDestinationItem) { _, newValue in
            updateCoordinates()
        }
    }
    
    private func updateCoordinates() {
        guard let start = selectedCurrentLocationItem?.placemark.coordinate,
              let end = selectedDestinationItem?.placemark.coordinate else { return }
        
        startCoordinate = start
        endCoordinate = end
        
        // Clear previous results
        routePlanner.clearRouteDetails()
        
        // Calculate new route
        routePlanner.findRouteOptions(from: start, to: end)
    }
    
    private var bottomPaddingForControls: CGFloat {
        switch currentDetent {
        case .height(300):
            return 320   // peek height
        case .height(500):
            return 520   // adjust to match your medium peek (≈ default 380–420)
        default:
            return 0
        }
    }

    private var currentLocationSearchField: some View {
        HStack {
            Image(systemName: "location.fill").foregroundColor(.blue)
            TextField("Search Starting Point", text: $currentLocationText)
                .textFieldStyle(.plain)
                .foregroundColor(isCurrentLocationFromDevice ? Color(hex: 0x003F50).opacity(0.6) : .primary)
                .focused($isCurrentLocationFieldFocused)
                .onSubmit {
                    isCurrentLocationFromDevice = false
                    triggerCurrentLocationSearch(performImmediateSearch: true)
                    isCurrentLocationFieldFocused = false
                }
                .onChange(of: currentLocationText) { _, newValue in
                    if isCurrentLocationFieldFocused {
                        isCurrentLocationFromDevice = false
                        if newValue.isEmpty { currentLocationResults = [] } else { triggerCurrentLocationSearch() }
                    }
                }
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .background(RoundedRectangle(cornerRadius: 30).fill(Color(.white)))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
    }
    
    private var destinationSearchField: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse").foregroundColor(destinationText.isEmpty ? .gray : .red)
            TextField("Search Destination", text: $destinationText)
                .textFieldStyle(.plain)
                .focused($isDestinationFieldFocused)
                .onSubmit {
                    triggerDestinationSearch(performImmediateSearch: true)
                    isDestinationFieldFocused = false
                }
                .onChange(of: destinationText) { _, newValue in
                     if isDestinationFieldFocused {
                        if newValue.isEmpty { destinationResults = [] } else { triggerDestinationSearch() }
                    }
                }
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .background(RoundedRectangle(cornerRadius: 30).fill(Color(.white)))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
    }

    private func suggestionRow(for item: MKMapItem) -> some View {
        VStack(alignment: .leading) {
            Text(item.name ?? "Unknown Location").font(.headline)
            Text(item.placemark.title ?? "").font(.subheadline).foregroundColor(.gray)
        }
    }

    private func handleAuthorizationChange(status: CLAuthorizationStatus) {
        if !initialRegionSet {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if let location = locationManager.userLocation {
                    cameraPosition = .region(MKCoordinateRegion(center: location.coordinate, span: userLocationZoomSpan))
                    initialRegionSet = true
                }
            case .denied, .restricted:
                cameraPosition = .region(defaultMapRegion)
                initialRegionSet = true
            case .notDetermined:
                locationManager.requestAuthorization()
                cameraPosition = .region(defaultMapRegion)
            @unknown default:
                cameraPosition = .region(defaultMapRegion)
                initialRegionSet = true
            }
        }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if let location = locationManager.userLocation, isCurrentLocationFromDevice {
                 reverseGeocode(location: location)
            }
        } else {
            if isCurrentLocationFromDevice {
                currentLocationText = "Location not available"
                geocodedCurrentLocationText = ""
            }
        }
    }

    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else { return }

            let address = [
                placemark.name,
                placemark.subLocality,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ].compactMap { $0 }.joined(separator: ", ")

            DispatchQueue.main.async {
                // Update your text fields as before
                if self.isCurrentLocationFromDevice || self.currentLocationText == self.geocodedCurrentLocationText {
                    self.currentLocationText = address
                    self.isCurrentLocationFromDevice = true
                }
                self.geocodedCurrentLocationText = address

                // ── NEW: now that we have a placemark + address, make the MKMapItem:
                let gpsPlacemark = MKPlacemark(coordinate: location.coordinate,
                                               addressDictionary: nil)
                let gpsItem = MKMapItem(placemark: gpsPlacemark)
                gpsItem.name = address
                self.selectedCurrentLocationItem = gpsItem

                // ── And if the user already picked a destination, show the sheet:
                if self.selectedDestinationItem != nil {
                    self.isDetailSheetPresented = true
                }
            }
        }
    }

    
    private func triggerSearch(for currentLocation: Bool, performImmediateSearch: Bool = false) {
        let taskToCancel = currentLocation ? currentLocationSearchTask : destinationSearchTask
        taskToCancel?.cancel()

        let newSearchTask = Task {
            do {
                if !performImmediateSearch {
                    try await Task.sleep(for: .milliseconds(150))
                }
                let query = currentLocation ? currentLocationText : destinationText
                guard !Task.isCancelled, !query.isEmpty else {
                    await MainActor.run {
                        if query.isEmpty {
                            if currentLocation { self.currentLocationResults = [] } else { self.destinationResults = [] }
                        }
                    }
                    return
                }
                await MainActor.run {
                    searchLocation(query: query, isForCurrentLocation: currentLocation)
                }
            } catch {
                 if Task.isCancelled { return }
                 print("Error in search task: \(error)")
                 await MainActor.run {
                    if currentLocation { self.currentLocationResults = [] } else { self.destinationResults = [] }
                 }
            }
        }
        if currentLocation { currentLocationSearchTask = newSearchTask } else { destinationSearchTask = newSearchTask }
    }

    private func triggerCurrentLocationSearch(performImmediateSearch: Bool = false) {
        triggerSearch(for: true, performImmediateSearch: performImmediateSearch)
    }
    private func triggerDestinationSearch(performImmediateSearch: Bool = false) {
        triggerSearch(for: false, performImmediateSearch: performImmediateSearch)
    }

    private func selectCurrentLocation(item: MKMapItem) {
        currentLocationText = item.name ?? item.placemark.title ?? "Selected Location"
        isCurrentLocationFromDevice = false
        selectedCurrentLocationItem = item
        if let coordinate = item.placemark.location?.coordinate {
            cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: userLocationZoomSpan))
        }
        currentLocationResults = []; isCurrentLocationFieldFocused = false
        
        if selectedDestinationItem != nil {
            isDetailSheetPresented = true
        }
    }

    private func selectDestination(item: MKMapItem) {
        destinationText = item.name ?? item.placemark.title ?? "Selected Destination"
        selectedDestinationItem = item
        if let coordinate = item.placemark.location?.coordinate {
            cameraPosition = .region(
                MKCoordinateRegion(center: coordinate, span: userLocationZoomSpan)
            )
        }
        destinationResults = []
        isDestinationFieldFocused = false
        
        if selectedCurrentLocationItem != nil {
            isDetailSheetPresented = true
        }
    }
    
    private func swapLocations() {
        // Swap text values
        let tempText = currentLocationText
        currentLocationText = destinationText
        destinationText = tempText
        
        // Swap selected items
        let tempItem = selectedCurrentLocationItem
        selectedCurrentLocationItem = selectedDestinationItem
        selectedDestinationItem = tempItem
        
        // Update device-based location flag
        isCurrentLocationFromDevice = false
    }
    
    // Restructured filter for Tangerang area
    private func isWithinTangerang(_ placemark: MKPlacemark) -> Bool {
        // Check 1: SubAdministrativeArea contains "Tangerang"
        if let subAdminArea = placemark.subAdministrativeArea {
            if subAdminArea.localizedCaseInsensitiveContains("Tangerang") {
                return true
            }
        }

        // Check 2: Locality checks
        if let locality = placemark.locality {
            // General check for "Tangerang" in locality (covers "Tangerang", "South Tangerang City", "Tangerang City")
            if locality.localizedCaseInsensitiveContains("Tangerang") {
                return true
            }
            // Check against specific known localities within broader Tangerang area
            for specificLocality in ContentView.tangerangSpecificLocalities {
                if locality.localizedCaseInsensitiveContains(specificLocality) {
                    return true
                }
            }
        }
        
        // Check 3: Name contains "Tangerang" AND AdministrativeArea (Province) is "Banten"
        if let name = placemark.name,
           let adminArea = placemark.administrativeArea { // Ensure adminArea is not nil before checking
            if name.localizedCaseInsensitiveContains("Tangerang") && adminArea.localizedCaseInsensitiveContains("Banten") {
                return true
            }
        }

        return false
    }

    private func searchLocation(query: String, isForCurrentLocation: Bool) {
        // First check if query matches any bus stop names
        let busStopResults = routePlanner.bsdBusStops.filter { stop in
            stop.name.localizedCaseInsensitiveContains(query)
        }.map { stop in
            let placemark = MKPlacemark(coordinate: stop.location)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = stop.name + " (Bus Stop)"
            return mapItem
        }
        
        // Then perform regular search if needed
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = tangerangSearchRegion
        
        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                let allResults = busStopResults + response.mapItems.filter { isWithinTangerang($0.placemark) }
                
                await MainActor.run {
                    if isForCurrentLocation {
                        self.currentLocationResults = allResults
                    } else {
                        self.destinationResults = allResults
                    }
                }
            } catch {
                // Fallback to just bus stops if search fails
                await MainActor.run {
                    if isForCurrentLocation {
                        self.currentLocationResults = busStopResults
                    } else {
                        self.destinationResults = busStopResults
                    }
                }
            }
        }
    }
}

struct DetailBottomSheetView: View {
    let mapItem: MKMapItem
    @Binding var isPresented: Bool
    @ObservedObject var routePlanner: RoutePlanner
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?
    @Binding var currentDetent: PresentationDetent
    @State private var showingRouteSteps = false
    @Binding var selectedCurrentLocationItem: MKMapItem?
    @Binding var selectedDestinationItem: MKMapItem?
  

    // Default waktu dari perangkat
    @State private var selectedHour = Calendar.current.component(.hour, from: Date())
    @State private var selectedMinute = Calendar.current.component(.minute, from: Date())
    
    private var isTimeValid: Bool {
        let totalMinutes = (selectedHour * 60) + selectedMinute
        return totalMinutes >= 5*60 && totalMinutes <= 21*60 + 30
    }
    
    private var hasValidRoutes: Bool {
        !routePlanner.suggestedRoutes.isEmpty && isTimeValid
    }
    
    var formattedBoardTime: String {
        return String(format: "%02d:%02d", selectedHour, selectedMinute)
    }
    
    var formattedETATime: String {
        // Calculate ETA based on selected time and route duration
        let calendar = Calendar.current
        let components = DateComponents(hour: selectedHour, minute: selectedMinute)
        guard let baseDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else {
            return "N/A"
        }
        
        // Calculate ETA by adding route duration (convert TimeInterval to minutes)
        let etaDate = baseDate.addingTimeInterval(routePlanner.suggestedRoutes.first?.totalTime ?? 0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: etaDate)
    }

    // Mode waktu

    // Array jam dan menit
    let hours = Array(0...23)
    let minutes = Array(0...59)
    private func calculateETA(for route: SuggestedRoute) -> String {
        let calendar = Calendar.current
        let components = DateComponents(hour: selectedHour, minute: selectedMinute)
        guard let baseDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else {
            return "N/A"
        }
        
        let etaDate = baseDate.addingTimeInterval(route.totalTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: etaDate)
    }

    var body: some View {
        VStack(spacing: 16) {
            if showingRouteSteps {
                RouteStepsView(
                    steps: routePlanner.routeSteps,
                    boardTime: formattedBoardTime,
                    etaTime: formattedETATime,
                    totalTime: routePlanner.suggestedRoutes.first?.formattedTotalTime ?? "N/A",
                    currentDetent: $currentDetent,
                    showingRouteSteps: $showingRouteSteps,
                    routePlanner: routePlanner
                )
            } else {
                VStack(alignment: .leading) {
                    
                    HStack {
                        Text("Board on")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    HStack(spacing: 2) {
                        Picker("Jam", selection: $selectedHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: 70)
                        .clipped()
                        .labelsHidden()
                        
                        Text(":")
                            .font(.title)
                        
                        Picker("Menit", selection: $selectedMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: 70)
                        .clipped()
                        .labelsHidden()
                    }
                    .frame(minHeight: 40, maxHeight: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(.white))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 0)
                        
                        VStack(alignment: .leading) {
                            Text("Suggested Routes")
                                .font(.system(size: 20))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 30)

                            if isTimeValid && !routePlanner.suggestedRoutes.isEmpty {
                                ScrollView {
                                    ForEach(Array(routePlanner.suggestedRoutes.enumerated()), id: \.element.id) { index, route in
                                        RouteItemCardView(
                                            index: index,
                                            formattedBoardTime: String(format: "%02d:%02d", selectedHour, selectedMinute),
                                            formattedETATime: calculateETA(for: route),
                                            route: route,
                                            onSelect: {
                                                if let start = startCoordinate,
                                                   let end = endCoordinate {
                                                    let startName = selectedCurrentLocationItem?.name ?? "Start Point"
                                                    let endName = selectedDestinationItem?.name ?? "Destination"
                                                    routePlanner.planSpecificRoute(
                                                        route,
                                                        from: start,
                                                        to: end,
                                                        startName: startName,
                                                        endName: endName
                                                    )
                                                    showingRouteSteps = true
                                                    currentDetent = .large
                                                }
                                            },
                                            currentDetent: $currentDetent
                                        )
                                        .padding()
                                    }
                                }
                            } else {
                                noRoutesView
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                
            }
        }
    }
    
    private var noRoutesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            if !isTimeValid {
                VStack(spacing: 8) {
                    Text("No buses available at this time")
                        .font(.headline)
                    Text("BSD Link operating hours: 05:00 - 21:30")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } else if routePlanner.suggestedRoutes.isEmpty {
                VStack(spacing: 8) {
                    Text("No available routes found")
                        .font(.headline)
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .multilineTextAlignment(.center)
        
    }
    
}


struct RouteItemCardView: View {
    let index: Int
    let formattedBoardTime: String
    let formattedETATime: String
    let route: SuggestedRoute
    let onSelect: () -> Void
    @Binding var currentDetent: PresentationDetent

    // Assign bus chip background color
    func busColor(for index: Int) -> Color {
        return index == 0 ? Color.blue.opacity(0.3) : Color.pink.opacity(0.3)
    }

    // Background color based on tab
    @ViewBuilder
    var cardBackgroundColor: some View {
        if index == 0 {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0xF1FFFF), Color(hex: 0xF5FFFA)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color(hex: 0xf2f2f2)
        }
    }

    var body: some View {
        VStack() {

            if index == 0 {
                HStack {
                    Text("Fastest")
                        .foregroundColor(Color(hex: 0x467F8E))
                        .padding(.bottom, -6)
                        .font(.system(size: 24))
                        .fontWeight(.medium)
                    Spacer()
                }
            }

            // Bus routes vertically stacked
            VStack() {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bus.fill")
                            .foregroundColor(.black)
                        Text("\(route.route.name)") // Show actual route name
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                            .background(Color(route.route.color).opacity(0.3)) // Use route's actual color
                            .foregroundColor(.black)
                            .cornerRadius(20)
                            .font(.system(size: 14))
                    }
                    .padding(.top, 8)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .lastTextBaseline) {
                Text(route.formattedTotalTime)
                    .font(.system(size: 40, weight: .semibold))
                    .padding(.top, -2)
                    .padding(.bottom, -2)
                    .foregroundColor(.black).opacity(0.8)

                VStack(alignment: .leading) {
                    Text("min")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black).opacity(0.8)
                        .padding(.leading, -8)
                }

                Spacer()

                Text("board on")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black).opacity(0.5)
                
                Text(formattedBoardTime) // Updated to use computed property
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.black).opacity(0.5)
                    .padding(.leading, -8)
                
                Text("ETA")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black).opacity(0.5)
                
                Text(formattedETATime) // Updated to use computed property
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.black).opacity(0.5)
                    .padding(.leading, -8)
            }


            HStack() {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))
                        Text("\(String(format: "%.1f", (route.walkingTimeToStart / 60) * 80 / 1000))")
                            .padding(.top, 6)
                            .padding(.leading, -2)
                            .font(.system(size: 16, weight:.medium))
                        Text("km")
                            .padding(.top, 9)
                            .padding(.leading, -4)
                            .font(.system(size: 12, weight:.medium))
                    }
                    .font(.subheadline)

                    HStack(spacing: 4) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 16))
                        Text("\(String(format: "%.1f", (route.busTravelTime / 60) * 30 / 100))")
                            .padding(.top, 6)
                            .padding(.leading, -2)
                            .font(.system(size: 16, weight:.medium))
                        Text("km")
                            .padding(.top, 9)
                            .padding(.leading, -4)
                            .font(.system(size: 12, weight:.medium))
                    }
                    .font(.subheadline)
                    .padding(.leading, -10)
                }
                .padding(.top, 0)

                Spacer()

                Button(action: {
                    onSelect()
                    currentDetent = .height(300)
                }) {
                    Text("details")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 6)
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        
                }
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
                .padding(.bottom, -5)
            
            }
            .frame(maxWidth: .infinity)
            .padding(.top, -4)

        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}





extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}

#Preview{
    ContentView()
}

#Preview {
    // Create mock data
    let routePlanner = RoutePlanner()
    
    // Create a mock route with some color
    let mockRoute = BusRoute(
        id: "R01",
        name: "Intermoda - Sektor 1.3",
        stops: [],
        color: .route1
    )
    
    // Set current route for color
    routePlanner.currentRoute = mockRoute
    routePlanner.currentRouteColor = Color(routePlanner.colorForRoute(mockRoute))
    
    // Create mock steps
    let mockSteps = [
        RouteStep(
            time: "14:30",
            location: "Current Location",
            address: nil,
            duration: nil,
            transportType: .walk,
            stops: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.3024, longitude: 106.6522)
        ),
        RouteStep(
            time: "14:35",
            location: "Walk to Intermoda Bus Stop",
            address: nil,
            duration: "5 min",
            transportType: .walk,
            stops: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.3024, longitude: 106.6522)
        ),
        RouteStep(
            time: "14:40",
            location: "Intermoda Bus Stop",
            address: "BSD Link Route 1",
            duration: nil,
            transportType: .bus,
            stops: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.3024, longitude: 106.6522)
        ),
        RouteStep(
            time: "14:45",
            location: "Cosmo",
            address: "The Breeze - AEON - ICE - The Breeze",
            duration: nil,
            transportType: .bus,
            stops: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.3121, longitude: 106.6486)
        ),
        RouteStep(
            time: "15:00",
            location: "The Breeze BSD",
            address: nil,
            duration: nil,
            transportType: .walk,
            stops: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.3013, longitude: 106.6531)
        )
    ]
    
    // Set the route steps
    routePlanner.routeSteps = mockSteps
    
    // Create the view with mock data
    return RouteStepsView(
        steps: mockSteps,
        boardTime: "14:30",
        etaTime: "15:00",
        totalTime: "30",
        currentDetent: .constant(.height(500)),
        showingRouteSteps: .constant(true),
        routePlanner: routePlanner
    )
    .previewDisplayName("Route Steps Preview")
}

#Preview {
    // Create mock data
    let routePlanner = RoutePlanner()
    
    // Create mock bus stops
    let startStop = BusStop(
        id: "BS01",
        name: "Intermoda",
        location: CLLocationCoordinate2D(latitude: -6.3199, longitude: 106.6437)
    )
    
    let endStop = BusStop(
        id: "BS27",
        name: "Griya Loka 1",
        location: CLLocationCoordinate2D(latitude: -6.3048, longitude: 106.6824)
    )
    
    // Create mock routes
    let mockRoute1 = BusRoute(
        id: "R01",
        name: "Intermoda - Sektor 1.3",
        stops: [startStop, endStop],
        color: .route1
    )
    
    let mockRoute2 = BusRoute(
        id: "R02",
        name: "Sektor 1.3 - Intermoda",
        stops: [startStop, endStop],
        color: .route2
    )
    
    // Create mock suggested routes
    let mockSuggestedRoutes = [
        SuggestedRoute(
            route: mockRoute1,
            startStop: startStop,
            endStop: endStop,
            walkingTimeToStart: 5 * 60, // 5 minutes
            busTravelTime: 15 * 60,     // 15 minutes
            walkingTimeToDestination: 3 * 60, // 3 minutes
            totalTime: 23 * 60,         // 23 minutes total
            schedules: ["14:30", "15:00", "15:30"]
        ),
        SuggestedRoute(
            route: mockRoute2,
            startStop: startStop,
            endStop: endStop,
            walkingTimeToStart: 7 * 60, // 7 minutes
            busTravelTime: 12 * 60,     // 12 minutes
            walkingTimeToDestination: 5 * 60, // 5 minutes
            totalTime: 24 * 60,         // 24 minutes total
            schedules: ["14:35", "15:05", "15:35"]
        )
    ]
    
    // Set the suggested routes
    routePlanner.suggestedRoutes = mockSuggestedRoutes
    
    // Create mock MKMapItem for destination
    let destinationPlacemark = MKPlacemark(
        coordinate: CLLocationCoordinate2D(latitude: -6.3048, longitude: 106.6824)
    )
    let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
    destinationMapItem.name = "Griya Loka 1"
    
    // Create the view with mock data
    return DetailBottomSheetView(
        mapItem: destinationMapItem,
        isPresented: .constant(true),
        routePlanner: routePlanner,
        startCoordinate: CLLocationCoordinate2D(latitude: -6.3199, longitude: 106.6437),
        endCoordinate: CLLocationCoordinate2D(latitude: -6.3048, longitude: 106.6824),
        currentDetent: .constant(.height(500)),
        selectedCurrentLocationItem: .constant(nil),
        selectedDestinationItem: .constant(destinationMapItem)
    )
    .previewDisplayName("Detail Bottom Sheet Preview")
}
