using Microsoft.AspNetCore.SignalR;
using BalanceGame.Services;
using BalanceGame.Models;
using System.Text.Json;

namespace BalanceGame.Hubs
{
    public class GameHub : Hub
    {
        private readonly GameRoomService _gameRoomService;
        private readonly GameHistoryService _historyService;
        
        public GameHub(GameRoomService gameRoomService, GameHistoryService historyService)
        {
            _gameRoomService = gameRoomService;
            _historyService = historyService;
        }
        
        public async Task JoinRoom(string roomCode, string username)
        {
            var room = _gameRoomService.GetRoom(roomCode);
            if (room == null)
            {
                await Clients.Caller.SendAsync("Error", "房間不存在");
                return;
            }
            
            var player = new Player
            {
                Username = username,
                ConnectionId = Context.ConnectionId,
                IsHost = room.HostUsername == username
            };
            
            if (!_gameRoomService.JoinRoom(roomCode, player))
            {
                await Clients.Caller.SendAsync("Error", "無法加入房間");
                return;
            }
            
            await Groups.AddToGroupAsync(Context.ConnectionId, roomCode);
            await Clients.Caller.SendAsync("JoinedRoom", roomCode);
            
            // Notify all players in room
            var players = _gameRoomService.GetRoomPlayers(roomCode);
            await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);
            await Clients.Group(roomCode).SendAsync("RoomUpdated", room);
            
            await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", $"{username} 加入了房間");
        }
        
        public async Task LeaveRoom(string roomCode, string username)
        {
            if (_gameRoomService.LeaveRoom(roomCode, username))
            {
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, roomCode);
                
                var players = _gameRoomService.GetRoomPlayers(roomCode);
                var room = _gameRoomService.GetRoom(roomCode);
                
                if (room != null)
                {
                    await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);
                    await Clients.Group(roomCode).SendAsync("RoomUpdated", room);
                    await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", $"{username} 離開了房間");
                }
            }
        }
          public async Task SetReady(string roomCode, string username, bool isReady)
        {
            if (_gameRoomService.SetPlayerReady(roomCode, username, isReady))
            {
                var players = _gameRoomService.GetRoomPlayers(roomCode);
                var room = _gameRoomService.GetRoom(roomCode);
                
                await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);

                // log all players' readiness status
                foreach (var player in players)
                {
                    Console.WriteLine($"Player: {player.Username}, IsReady: {player.IsReady},Room:{room.State}");
                }
                
                string status = isReady ? "準備" : "取消準備";
                await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", $"{username} {status}");
                
                // Check if we should start next round (when game is showing results)
                if (room != null && room.State == GameState.ShowingResults)
                {
                    var activePlayers = players.Where(p => !p.IsEliminated).ToList();
                    
                    // If all active players are ready, start next round
                    if (activePlayers.Count > 1 && activePlayers.All(p => p.IsReady))
                    {
                        // Reset players for next round
                        foreach (var player in activePlayers)
                        {
                            player.IsReady = false;
                            player.HasSubmitted = false;
                            player.CurrentNumber = null;
                        }
                          // Start next round
                        room.State = GameState.Playing;
                        await Clients.Group(roomCode).SendAsync("GameStarted", room);
                        await Clients.Group(roomCode).SendAsync("RoomUpdated", room);
                        await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);
                        await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", "下一輪開始！請在時間內選擇一個 0-100 的數字");
                        
                        // Start countdown timer for next round
                        _ = Task.Run(async () =>
                        {
                            await Task.Delay(room.RoundTimeSeconds * 1000);
                            await ForceEndRound(roomCode);
                        });
                    }
                }
            }
        }
        
        public async Task StartGame(string roomCode, string hostUsername)
        {
            if (_gameRoomService.StartGame(roomCode, hostUsername))
            {
                var room = _gameRoomService.GetRoom(roomCode);
                await Clients.Group(roomCode).SendAsync("GameStarted", room);
                await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", "遊戲開始！請在時間內選擇一個 0-100 的數字");
                
                // Start countdown timer
                _ = Task.Run(async () =>
                {
                    await Task.Delay(room!.RoundTimeSeconds * 1000);
                    await ForceEndRound(roomCode);
                });
            }
            else
            {
                await Clients.Caller.SendAsync("Error", "無法開始遊戲，請確保所有玩家都已準備");
            }
        }
        
        public async Task SubmitNumber(string roomCode, string username, int number)
        {
            if (_gameRoomService.SubmitNumber(roomCode, username, number))
            {
                await Clients.Caller.SendAsync("NumberSubmitted", number);
                await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", $"{username} 已提交數字");
                
                // Check if all players have submitted
                var players = _gameRoomService.GetRoomPlayers(roomCode)
                    .Where(p => !p.IsEliminated).ToList();
                    
                if (players.All(p => p.HasSubmitted))
                {
                    await CalculateAndShowResults(roomCode);
                }
                else
                {
                    Console.WriteLine($"Player {string.Join(",",players.Where(i => i.HasSubmitted == false).Select(i => i.Username).ToList())} 未提交數字");
                }
            }
            else
            {
                await Clients.Caller.SendAsync("Error", "提交數字失敗");
            }
        }
        
        public async Task SendChatMessage(string roomCode, string username, string message)
        {
            var room = _gameRoomService.GetRoom(roomCode);
            if (room != null && room.AllowChat)
            {
                await Clients.Group(roomCode).SendAsync("ChatMessage", username, message);
            }
        }
        
        public async Task UpdateRoomSettings(string roomCode, string hostUsername, int roundTimeSeconds, bool allowChat)
        {
            if (_gameRoomService.UpdateRoomSettings(roomCode, hostUsername, roundTimeSeconds, allowChat))
            {
                var room = _gameRoomService.GetRoom(roomCode);
                await Clients.Group(roomCode).SendAsync("RoomUpdated", room);
                await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", "房間設定已更新");
            }
            else
            {
                await Clients.Caller.SendAsync("Error", "無法更新房間設定");
            }
        }
        
        private async Task ForceEndRound(string roomCode)
        {
            // Auto-submit random numbers for players who haven't submitted
            var players = _gameRoomService.GetRoomPlayers(roomCode)
                .Where(p => !p.IsEliminated && !p.HasSubmitted).ToList();
                
            var random = new Random();
            foreach (var player in players)
            {
                _gameRoomService.SubmitNumber(roomCode, player.Username, random.Next(0, 101));
            }
            
            await CalculateAndShowResults(roomCode);
        }

        private async Task CalculateAndShowResults(string roomCode)
        {
            Console.WriteLine("Calculating results for room: " + roomCode);
            var result = _gameRoomService.CalculateResults(roomCode);
            var players = _gameRoomService.GetRoomPlayers(roomCode);
            
            if (result == null)
            {
                await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", "無法計算結果，請重新操作");
                await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);
                return;
            }

            await Clients.Group(roomCode).SendAsync("RoundResults", result);

            // Save to history
            await _historyService.SaveGameResultAsync(roomCode, result);

            var room = _gameRoomService.GetRoom(roomCode);
            await Clients.Group(roomCode).SendAsync("RoomUpdated", room);
            await Clients.Group(roomCode).SendAsync("PlayersUpdated", players);

            if (room!.State == GameState.Finished)
            {
                var winner = players.FirstOrDefault(p => !p.IsEliminated);
                if (winner != null)
                {
                    await Clients.Group(roomCode).SendAsync("GameFinished", winner.Username);
                    await Clients.Group(roomCode).SendAsync("ChatMessage", "系統", $"遊戲結束！恭喜 {winner.Username} 獲勝！");
                }
            }
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            // Handle disconnection - you might want to mark player as disconnected
            // instead of removing them immediately
            await base.OnDisconnectedAsync(exception);
        }
    }
}
