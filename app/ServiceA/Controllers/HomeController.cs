using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using ServiceA.Models;
using System.Net.Http;
using System.Threading.Tasks;

namespace ServiceA.Controllers;

public class HomeController : Controller
{
    private readonly HttpClient _httpClient;

    public HomeController(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpGet]
    public async Task<IActionResult> GetCountry()
    {
        var response = await _httpClient.GetStringAsync("http://serviceb.service-connect-demo-namespace:8080/country");
        Console.WriteLine(response);
        return Json(new { country = response });
    }
}
