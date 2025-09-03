using Microsoft.AspNetCore.Mvc;
using BalanceGame.Services;

namespace BalanceGame.Controllers
{
    public class AccountController : Controller
    {
        private readonly UserService _userService;
        
        public AccountController(UserService userService)
        {
            _userService = userService;
        }
        
        [HttpGet]
        public IActionResult Login()
        {
            return View();
        }
        
        [HttpPost]
        public async Task<IActionResult> Login(string username, string password)
        {
            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            {
                ViewBag.Error = "請輸入用戶名和密碼";
                return View();
            }
            
            var user = await _userService.AuthenticateAsync(username, password);
            if (user != null)
            {
                HttpContext.Session.SetString("Username", user.Username);
                HttpContext.Session.SetInt32("UserId", user.Id);
                return RedirectToAction("Index", "Home");
            }
            
            ViewBag.Error = "用戶名或密碼錯誤";
            return View();
        }
        
        [HttpGet]
        public IActionResult Register()
        {
            return View();
        }
        
        [HttpPost]
        public async Task<IActionResult> Register(string username, string password, string confirmPassword)
        {
            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            {
                ViewBag.Error = "請輸入用戶名和密碼";
                return View();
            }
            
            if (password != confirmPassword)
            {
                ViewBag.Error = "密碼確認不匹配";
                return View();
            }
            
            if (username.Length < 3 || username.Length > 20)
            {
                ViewBag.Error = "用戶名長度必須在 3-20 字符之間";
                return View();
            }
            
            if (password.Length < 4)
            {
                ViewBag.Error = "密碼長度至少 4 個字符";
                return View();
            }
            
            var user = await _userService.RegisterAsync(username, password);
            if (user != null)
            {
                HttpContext.Session.SetString("Username", user.Username);
                HttpContext.Session.SetInt32("UserId", user.Id);
                return RedirectToAction("Index", "Home");
            }
            
            ViewBag.Error = "用戶名已存在";
            return View();
        }
        
        [HttpPost]
        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return RedirectToAction("Login");
        }
    }
}
