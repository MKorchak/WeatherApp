//
//  WeatherViewController.swift
//  WeatherApp
//
//  Created by Misha Korchak on 15.02.17.
//  Copyright © 2017 Misha Korchak. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class WeatherViewController: UIViewController, CLLocationManagerDelegate, NSFetchedResultsControllerDelegate, WeatherGetterDelegate {
    
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var cityLabel: UILabel!
    @IBOutlet weak var cityImageView: UIImageView!
    @IBOutlet weak var weatherImageView: UIImageView!
    @IBOutlet weak var locationIcon: UIImageView!
    
    private let locationManager = CLLocationManager()
    private var weather: WeatherGetter!
    private var weatherData: WeatherData!
    
    var pageIndex: Int!
    var city: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(city == "Location") {
            weather = WeatherGetter(delegate: self)
            getLocation()
            locationIcon.image = UIImage(named: "Location Icon")
        }
        else {
            weather = WeatherGetter(delegate: self)
            weather.getWeatherByCity(city.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlUserAllowed)!)
        }
        cityImageView.image = UIImage(named: city)
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func getLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            showSimpleAlert(
                self,
                title: "Please turn on location services",
                message: "This app needs location services in order to report the weather " +
                    "for your current location.\n" +
                "Go to Settings → Privacy → Location Services and turn location services on."
            )
            return
        }
        
        let authStatus = CLLocationManager.authorizationStatus()
        guard authStatus == .authorizedWhenInUse else {
            switch authStatus {
            case .denied, .restricted:
                let alert = UIAlertController(
                    title: "Location services for this app are disabled",
                    message: "In order to get your current location, please open Settings for this app, choose \"Location\"  and set \"Allow location access\" to \"While Using the App\".",
                    preferredStyle: .alert
                )
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                let openSettingsAction = UIAlertAction(title: "Open Settings", style: .default) {
                    action in
                    if let url = URL(string: UIApplicationOpenSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
                alert.addAction(cancelAction)
                alert.addAction(openSettingsAction)
                self.present(alert, animated: true, completion: nil)
                return
                
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                
            default:
                print("Oops! Shouldn't have come this far.")
            }
            
            return
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        weather.getWeatherByCoordinates(latitude: newLocation.coordinate.latitude,
                                        longitude: newLocation.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.showSimpleAlert(self, title: "Can't determine your location",
                                 message: "The GPS and other location services aren't responding.")
        }
        print("locationManager didFailWithError: \(error)")
    }
    
    func didGetWeather(_ weather: Weather) {
        DispatchQueue.main.async {
            self.cityLabel.text = weather.city
            self.weatherLabel.text = weather.weatherDescription.capitalized
            if(weather.tempCelsius > 0) {
                self.temperatureLabel.text = "+\(Int(round(weather.tempCelsius)))°"
            }
            else {
                self.temperatureLabel.text = "\(Int(round(weather.tempCelsius)))°"
            }
            var imageURL: String?
            imageURL = "http://openweathermap.org/img/w/\(weather.weatherIconID).png"
            if let url = NSURL(string: imageURL!) {
                if let data = NSData(contentsOf: url as URL) {
                    self.weatherImageView.image = UIImage(data: data as Data)
                }
            }
            if let managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
                let fetchRequest: NSFetchRequest<WeatherData> = WeatherData.fetchRequest()
                do {
                    let searchResults = try managedObjectContext.fetch(fetchRequest)
                    for result in searchResults as [NSManagedObject] {
                        if(result.value(forKey: "city") as? String! == self.city) {
                            let managedObjectData:NSManagedObject = result
                            managedObjectContext.delete(managedObjectData)
                            print("weather deleted")
                        }
                    }
                } catch {
                    print("Error with request: \(error)")
                }
                self.weatherData = NSEntityDescription.insertNewObject(forEntityName: "WeatherData", into: managedObjectContext) as? WeatherData

                self.weatherData.city = self.cityLabel.text!
                self.weatherData.temperature = self.temperatureLabel.text!
                self.weatherData.weather = self.weatherLabel.text!
                self.weatherData.image = UIImagePNGRepresentation(self.weatherImageView.image!) as NSData?

                do {
                    try managedObjectContext.save()
                    print("weather saved")
                } catch {
                    print(error)
                    return
                }
            }
        }
    }
    
    func didNotGetWeather(_ error: NSError) {
        DispatchQueue.main.async {
            let fetchRequest: NSFetchRequest<WeatherData> = WeatherData.fetchRequest()
            self.weatherLabel.text = "-"
            self.temperatureLabel.text = "-"
            if(self.city != "Location") {
                self.cityLabel.text = self.city
            }
            else {
                self.cityLabel.text = "-"
            }
            do {
                let searchResults = try (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext.fetch(fetchRequest)
                for result in searchResults as [NSManagedObject] {
                    if(result.value(forKey: "city") as! String? == self.city) {
                        self.cityLabel.text = result.value(forKey: "city") as! String?
                        self.temperatureLabel.text = result.value(forKey: "temperature") as! String?
                        self.weatherLabel.text = result.value(forKey: "weather") as! String?
                        self.weatherImageView.image = UIImage(data: (result.value(forKey: "image")) as! Data)
                    }
                    else if(self.pageIndex == 0 && self.city == "Location") {
                        self.cityLabel.text = result.value(forKey: "city") as! String?
                        self.temperatureLabel.text = result.value(forKey: "temperature") as! String?
                        self.weatherLabel.text = result.value(forKey: "weather") as! String?
                        self.weatherImageView.image = UIImage(data: (result.value(forKey: "image")) as! Data)
                    }
                }
            } catch {
                print("Error with request: \(error)")
            }
        }
        print("didNotGetWeather error: \(error)")
    }
    
    private func showSimpleAlert(_ viewController: UIViewController, title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(
            title: "OK",
            style:  .default,
            handler: nil
        )
        alert.addAction(okAction)
        viewController.present(
            alert,
            animated: true,
            completion: nil
        )
    }
}
