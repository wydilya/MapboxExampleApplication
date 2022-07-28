//
//  ViewController.swift
//  MapboxExampleProject
//
//  Created by Ilya Zelkin on 28.07.2022.
//

import MapboxMaps
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

class ViewController: UIViewController {
    var navigationMapView: NavigationMapView!
    var navigationViewController: NavigationViewController!
    var routeOptions: NavigationRouteOptions?
    var routeResponse: RouteResponse?
    var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigationMapView)
        
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        navigationMapView.userLocationStyle = .puck2D()
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        navigationMapView.addGestureRecognizer(longPress)
        
        displayStartButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startButton.layer.cornerRadius = startButton.bounds.midY
        startButton.clipsToBounds = true
        startButton.setNeedsDisplay()
    }
  
    func displayStartButton() {
        startButton = UIButton()
        
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.backgroundColor = .blue
        startButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startButton.addTarget(self, action: #selector(tappedButton(sender:)), for: .touchUpInside)
        startButton.isHidden = true
        view.addSubview(startButton)
        
        startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
  
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        let point = sender.location(in: navigationMapView)
        let coordinate = navigationMapView.mapView.mapboxMap.coordinate(for: point)

        if let origin = navigationMapView.mapView.location.latestLocation?.coordinate {
            calculateRoute(from: origin, to: coordinate)
        } else {
            print("Failed to get user location, make sure to allow location access for this application.")
        }
    }
   
    @objc func tappedButton(sender: UIButton) {
        guard let routeResponse = routeResponse, let navigationRouteOptions = routeOptions else { return }
        
        navigationViewController = NavigationViewController(for: routeResponse, routeIndex: 0,
                                                                routeOptions: navigationRouteOptions)
        navigationViewController.modalPresentationStyle = .fullScreen
        
        present(navigationViewController, animated: true, completion: nil)
    }
    
    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")

        let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)

        Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                strongSelf.routeResponse = response
                strongSelf.routeOptions = routeOptions

                strongSelf.startButton?.isHidden = false

                strongSelf.drawRoute(route: route)
                
                strongSelf.navigationMapView.showWaypoints(on: route)
            }
        }
    }
  
    func drawRoute(route: Route) {
        guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
        guard let mapView = navigationMapView.mapView else { return }
        let sourceIdentifier = "routeStyle"
        
        let feature = Feature(geometry: .lineString(LineString(routeShape.coordinates)))
     
        if mapView.mapboxMap.style.sourceExists(withId: sourceIdentifier) {
            try? mapView.mapboxMap.style.updateGeoJSONSource(withId: sourceIdentifier, geoJSON: .feature(feature))
        } else {
            var geoJSONSource = GeoJSONSource()
            geoJSONSource.data = .feature(feature)
            try? mapView.mapboxMap.style.addSource(geoJSONSource, id: sourceIdentifier)
            
            var lineLayer = LineLayer(id: "routeLayer")
            lineLayer.source = sourceIdentifier
            lineLayer.lineColor = .constant(.init(UIColor(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1.0)))
            lineLayer.lineWidth = .constant(3)
            
            try? mapView.mapboxMap.style.addLayer(lineLayer)
        }
    }
}
