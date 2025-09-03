using Microsoft.AspNetCore.Mvc;
using BalanceGame.Services;

namespace BalanceGame.Controllers
{
    public class HomeController : Controller
    {
        private readonly UserService _userService;
        
        public HomeController(UserService userService)
        {
            _userService = userService;
        }
        
        public IActionResult Index()
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            return View();
        }
        
        public IActionResult Privacy()
        {
            return View();
        }
        
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View();
        }
    }
}
