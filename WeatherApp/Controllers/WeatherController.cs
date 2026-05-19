using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using DotNetEnv;
using WeatherApp.Models;

namespace WeatherApp.Controllers;

public class WeatherController : Controller {
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;

    public WeatherController() {
        _httpClient = new HttpClient();
        _apiKey = Environment.GetEnvironmentVariable("OPENWEATHER_API_KEY")
                  ?? throw new InvalidOperationException("OPENWEATHER_API_KEY is not set");
    }

    public IActionResult Index() {
        var countries = new List<Country> {
            new() { Code = "PL", Name = "Poland" },
            new() { Code = "DE", Name = "Germany" },
            new() { Code = "FR", Name = "France" },
            new() { Code = "US", Name = "USA" },
            new() { Code = "GB", Name = "Great Britain" },
            new() { Code = "IT", Name = "Italy" },
            new() { Code = "ES", Name = "Spain" },
            new() { Code = "RU", Name = "Russia" }
        };
        
        var cities = new Dictionary<string, List<City>> {
            ["PL"] = new() { new() { Name = "Warsaw" }, new() { Name = "Krakow" }, new() { Name = "Gdansk" }, new() { Name = "Wroclaw" }, new() { Name = "Lublin" } },
            ["DE"] = new() { new() { Name = "Berlin" }, new() { Name = "Munich" }, new() { Name = "Hamburg" }, new() { Name = "Cologne" } },
            ["FR"] = new() { new() { Name = "Paris" }, new() { Name = "Marseille" }, new() { Name = "Lyon" }, new() { Name = "Bordeaux" }},
            ["US"] = new() { new() { Name = "New York" }, new() { Name = "Los Angeles" }, new() { Name = "Chicago" }, new() { Name = "Dallas" } },
            ["GB"] = new() { new() { Name = "London" }, new() { Name = "Manchester" }, new() { Name = "Birmingham" } },
            ["IT"] = new() { new() { Name = "Rome" }, new() { Name = "Milan" }, new() { Name = "Naples" } },
            ["ES"] = new() { new() { Name = "Madrid" }, new() { Name = "Barcelona" }, new() { Name = "Valencia" } },
            ["RU"] = new() { new() { Name = "Moscow" }, new() { Name = "Saint Petersburg" }, new() { Name = "Kazan" }, new() { Name = "Vladivostok" } }
        };
        
        ViewBag.Countries = countries;
        ViewBag.CitiesJson = JsonSerializer.Serialize(cities);
        return View();
        
    }

    [HttpPost]
    public async Task<IActionResult> GetWeather(string country, string city) {
        if (string.IsNullOrEmpty(country) || string.IsNullOrEmpty(city)) {
            return BadRequest("Choose country and city");
        }

        try {
            var url =
                $"https://api.openweathermap.org/data/2.5/weather?q={city},{country}&appid={_apiKey}&units=metric&lang=en"; 
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode) {
                return Json(new { error = "Weather cannot be downloaded, please check data or API key" });
            }

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var weather = new {
                city = city, 
                country = country,
                temperature = root.GetProperty("main").GetProperty("temp").GetDouble(),
                feelsLike = root.GetProperty("main").GetProperty("feels_like").GetDouble(),  
                pressure = root.GetProperty("main").GetProperty("pressure").GetInt32(),
                humidity = root.GetProperty("main").GetProperty("humidity").GetInt32(),  
                wind = root.GetProperty("wind").GetProperty("speed").GetDouble(),  
                description = root.GetProperty("weather")[0].GetProperty("description").GetString(),
                icon = root.GetProperty("weather")[0].GetProperty("icon").GetString()
            };
            return Json(weather);
        }
        catch (Exception ex) {
            return Json(new { error = ex.Message });
        }
    }
}
