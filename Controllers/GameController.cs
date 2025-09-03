using Microsoft.AspNetCore.Mvc;
using BalanceGame.Services;

namespace BalanceGame.Controllers
{
    public class GameController : Controller
    {
        private readonly GameRoomService _gameRoomService;
        private readonly GameHistoryService _historyService;
        
        public GameController(GameRoomService gameRoomService, GameHistoryService historyService)
        {
            _gameRoomService = gameRoomService;
            _historyService = historyService;
        }
        
        [HttpGet]
        public IActionResult CreateRoom()
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            return View();
        }
        
        [HttpPost]
        public IActionResult CreateRoom(string dummy)
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            var room = _gameRoomService.CreateRoom(username);
            if (room != null)
            {
                return RedirectToAction("Room", new { roomCode = room.RoomCode });
            }
            
            ViewBag.Error = "創建房間失敗";
            return View();
        }
        
        [HttpGet]
        public IActionResult JoinRoom()
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            return View();
        }
        
        [HttpPost]
        public IActionResult JoinRoom(string roomCode)
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            if (string.IsNullOrWhiteSpace(roomCode) || roomCode.Length != 5)
            {
                ViewBag.Error = "請輸入有效的 5 位數房間號碼";
                return View();
            }
            
            var room = _gameRoomService.GetRoom(roomCode.ToUpper());
            if (room == null)
            {
                ViewBag.Error = "房間不存在";
                return View();
            }
            
            return RedirectToAction("Room", new { roomCode = roomCode.ToUpper() });
        }
        
        [HttpGet]
        public IActionResult Room(string roomCode)
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            var room = _gameRoomService.GetRoom(roomCode);
            if (room == null)
            {
                return RedirectToAction("JoinRoom");
            }
            
            ViewBag.Username = username;
            ViewBag.RoomCode = roomCode;
            return View(room);
        }
        
        [HttpGet]
        public async Task<IActionResult> History()
        {
            var username = HttpContext.Session.GetString("Username");
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }
            
            var history = await _historyService.GetUserHistoryAsync(username);
            return View(history);
        }
    }
}
