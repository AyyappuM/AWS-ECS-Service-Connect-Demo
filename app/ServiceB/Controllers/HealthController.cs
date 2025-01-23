using Microsoft.AspNetCore.Mvc;

namespace ServiceB.Controllers;

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
