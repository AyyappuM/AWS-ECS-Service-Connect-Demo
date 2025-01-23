using Microsoft.AspNetCore.Mvc;

namespace ServiceB.Controllers;

[ApiController]
[Route("[controller]")]
public class CountryController : ControllerBase
{
    private static readonly List<string> Countries = new List<string>
    {
        "Australia",
        "Brazil",
        "Canada",
        "China",
        "France",
        "Germany",
        "India",
        "Japan",
        "Russia",
        "South Africa",
        "UK",
        "USA"
    };

    [HttpGet]
    public ActionResult<string> Get()
    {
        var random = new Random();
        int index = random.Next(Countries.Count);
        return Countries[index];
    }
}
