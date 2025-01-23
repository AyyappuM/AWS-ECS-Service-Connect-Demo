using Microsoft.AspNetCore.Mvc;

namespace ServiceA.Controllers;

[ApiController]
[Route("[controller]")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public ActionResult<string> Get()
    {
        return "healthy";
    }
}