using BalanceGame.Models;
using System.Collections.Concurrent;
using System.Text.Json;

namespace BalanceGame.Services
{
    public class GameRoomService
    {
        private readonly ConcurrentDictionary<string, GameRoom> _rooms = new();
        private readonly ConcurrentDictionary<string, List<Player>> _roomPlayers = new();
        private readonly Random _random = new();
        
        public GameRoom? CreateRoom(string hostUsername)
        {
            string roomCode;
            do
            {
                roomCode = GenerateRoomCode();
            } while (_rooms.ContainsKey(roomCode));
            
            var room = new GameRoom
            {
                RoomCode = roomCode,
                HostUsername = hostUsername
            };
            
            _rooms[roomCode] = room;
            _roomPlayers[roomCode] = new List<Player>();
            
            return room;
        }
        
        public GameRoom? GetRoom(string roomCode)
        {
            _rooms.TryGetValue(roomCode, out var room);
            return room;
        }
        
        public List<Player> GetRoomPlayers(string roomCode)
        {
            _roomPlayers.TryGetValue(roomCode, out var players);
            return players ?? new List<Player>();
        }
        
        public bool JoinRoom(string roomCode, Player player)
        {
            if (!_rooms.ContainsKey(roomCode) || !_roomPlayers.ContainsKey(roomCode))
                return false;
                
            var players = _roomPlayers[roomCode];
            var room = _rooms[roomCode];
            
            if (players.Count >= 20 || room.State != GameState.Waiting)
                return false;
                
            // Check if username already exists in room
            if (players.Any(p => p.Username == player.Username))
                return false;
                
            players.Add(player);
            return true;
        }
        
        public bool LeaveRoom(string roomCode, string username)
        {
            if (!_roomPlayers.ContainsKey(roomCode))
                return false;
                
            var players = _roomPlayers[roomCode];
            var player = players.FirstOrDefault(p => p.Username == username);
            
            if (player == null)
                return false;
                
            players.Remove(player);
            
            // If host leaves, assign new host or close room
            if (player.IsHost && players.Any())
            {
                players.First().IsHost = true;
                _rooms[roomCode].HostUsername = players.First().Username;
            }
            else if (!players.Any())
            {
                // Remove empty room
                _rooms.TryRemove(roomCode, out _);
                _roomPlayers.TryRemove(roomCode, out _);
            }
            
            return true;
        }
        
        public bool StartGame(string roomCode, string hostUsername)
        {
            if (!_rooms.ContainsKey(roomCode) || !_roomPlayers.ContainsKey(roomCode))
                return false;
                
            var room = _rooms[roomCode];
            var players = _roomPlayers[roomCode];
            
            if (room.HostUsername != hostUsername || room.State != GameState.Waiting)
                return false;
                
            if (players.Count < 2 || !players.All(p => p.IsReady))
                return false;
                
            room.State = GameState.Playing;
            room.CurrentRound++;
            room.RoundStartTime = DateTime.Now;
            
            // Reset player submissions
            foreach (var player in players)
            {
                player.CurrentNumber = null;
                player.HasSubmitted = false;
            }
            
            return true;
        }
        
        public bool SubmitNumber(string roomCode, string username, int number)
        {
            if (!_roomPlayers.ContainsKey(roomCode))
            {
                Console.WriteLine($"Room {roomCode} does not exist.");
                return false;
            }
                
            var players = _roomPlayers[roomCode];
            var player = players.FirstOrDefault(p => p.Username == username);

            if (player == null || player.HasSubmitted || player.IsEliminated)
            {
                Console.WriteLine($"Player {username} is HasSubmitted:{player?.HasSubmitted}, IsEliminated:{player?.IsEliminated} so cannot submit number.");
                return false;
            }

            if (number < 0 || number > 100)
            {
                Console.WriteLine($"Player {username} submitted an invalid number: {number}.");
                return false;
            }
                
            player.CurrentNumber = number;
            player.HasSubmitted = true;
            
            return true;
        }
        
        public GameResult? CalculateResults(string roomCode)
        {
            if (!_rooms.ContainsKey(roomCode) || !_roomPlayers.ContainsKey(roomCode))
                return null;
                
            var room = _rooms[roomCode];
            var noneEliminatedPlayers = _roomPlayers[roomCode].Where(p => !p.IsEliminated).ToList();
            
            if (!noneEliminatedPlayers.All(p => p.HasSubmitted))
            {
                ResetPlayer(noneEliminatedPlayers);
                return null;
            }
                
            var numbers = noneEliminatedPlayers.Where(p => p.CurrentNumber.HasValue)
                                .Select(p => p.CurrentNumber!.Value)
                                .ToList();

            if (numbers.Count == 0)
            {
                ResetPlayer(noneEliminatedPlayers);
                return null;
            }
                
            // Apply game rules based on player count
            var validPlayers = ApplyGameRules(noneEliminatedPlayers);
            var validNumbers = validPlayers.Where(p => p.CurrentNumber.HasValue)
                                         .Select(p => p.CurrentNumber!.Value)
                                         .ToList();
            
            if (validNumbers.Count == 0)
            {
                
                return null;
            }
                
            double average = validNumbers.Average();
            double target = average * 0.8;
            
            var results = new List<PlayerResult>();
            string winnerUsername = "";
            double minDistance = double.MaxValue;
            
            // Special rule for 2 players with someone choosing 100
            bool reverseRule = noneEliminatedPlayers.Count <= 2 && noneEliminatedPlayers.Any(p => p.CurrentNumber == 100);
            
            foreach (var player in noneEliminatedPlayers)
            {
                if (!player.CurrentNumber.HasValue)
                    continue;
                    
                double distance = Math.Abs(player.CurrentNumber.Value - target);
                
                if (reverseRule)
                {
                    // In reverse rule, furthest from average wins
                    double avgDistance = Math.Abs(player.CurrentNumber.Value - average);
                    if (avgDistance > minDistance)
                    {
                        minDistance = avgDistance;
                        winnerUsername = player.Username;
                    }
                }
                else
                {
                    if (distance < minDistance)
                    {
                        minDistance = distance;
                        winnerUsername = player.Username;
                    }
                }
                
                results.Add(new PlayerResult
                {
                    Username = player.Username,
                    Number = player.CurrentNumber.Value,
                    Distance = distance
                });
            }
            
            UpdateScore(results, noneEliminatedPlayers, winnerUsername, target);

            ResetPlayer(noneEliminatedPlayers);

            // Check if game should end
            var remainingPlayers = noneEliminatedPlayers.Count(p => !p.IsEliminated);
            room.State = remainingPlayers <= 1 ? GameState.Finished : GameState.ShowingResults;
            
            return new GameResult
            {
                AverageNumber = average,
                TargetNumber = target,
                WinnerUsername = winnerUsername,
                Results = results
            };
        }

        private static void ResetPlayer(List<Player> noneEliminatedPlayers)
        {
            // Reset for next round
            foreach (var player in noneEliminatedPlayers)
            {
                player.CurrentNumber = null;
                player.HasSubmitted = false;
                player.IsReady = false;
            }
        }

        private void UpdateScore(List<PlayerResult> playersScoreboard, List<Player> noneEliminatedPlayers, string winnerUsername, double target)
        {
            var winner = noneEliminatedPlayers.FirstOrDefault(p => p.Username == winnerUsername);

            if (winner != null)
            {
                playersScoreboard.First(i => i.Username == winnerUsername).IsWinner = true;
            }
            
            int penalty = GetPenalty(noneEliminatedPlayers.Count, target, winner?.CurrentNumber);

            foreach (var result in playersScoreboard)
            {
                if (result.IsWinner)
                {
                    continue;
                }
                
                var player = noneEliminatedPlayers.First(p => p.Username == result.Username);
                player.Score -= penalty;
                result.ScoreChange = -penalty;
                result.TotalScore = player.Score;

                // Check elimination
                if (player.Score <= -10)
                {
                    player.IsEliminated = true;
                    result.IsEliminated = true;
                }
            }
        }

        private List<Player> ApplyGameRules(List<Player> players)
        {
            // Rule 1: If 4 or fewer players and duplicate numbers exist, invalidate those numbers
            if (players.Count <= 4)
            {
                var numberGroups = players.Where(p => p.CurrentNumber.HasValue)
                                        .GroupBy(p => p.CurrentNumber!.Value)
                                        .Where(g => g.Count() > 1)
                                        .SelectMany(g => g)
                                        .ToList();
                
                foreach (var player in numberGroups)
                {
                    player.CurrentNumber = null; // Invalidate duplicate numbers
                    player.Score -= 1; // Direct penalty
                }
            }
            
            return players.Where(p => p.CurrentNumber.HasValue).ToList();
        }
        
        private int GetPenalty(int playerCount, double target, int? winnerPlayerNumber)
        {
            // Rule 2: If 3 or fewer players and exact match (rounded), loser gets 2 points penalty
            if (winnerPlayerNumber != null && playerCount <= 3 && Math.Abs(winnerPlayerNumber.Value - Math.Round(target)) < 0.001)
            {
                return 2;
            }
            
            return 1; // Default penalty
        }
        
        public bool UpdateRoomSettings(string roomCode, string hostUsername, int roundTimeSeconds, bool allowChat)
        {
            if (!_rooms.ContainsKey(roomCode))
                return false;
                
            var room = _rooms[roomCode];
            if (room.HostUsername != hostUsername || room.State != GameState.Waiting)
                return false;
                
            room.RoundTimeSeconds = roundTimeSeconds;
            room.AllowChat = allowChat;
            
            return true;
        }
        
        public Player? GetPlayer(string roomCode, string username)
        {
            return !_roomPlayers.TryGetValue(roomCode, out List<Player>? value) ? null : value.FirstOrDefault(p => p.Username == username);
        }
        
        public bool SetPlayerReady(string roomCode, string username, bool isReady)
        {
            var player = GetPlayer(roomCode, username);
            if (player == null || player.IsEliminated)
                return false;
                
            player.IsReady = isReady;
            return true;
        }
        
        private string GenerateRoomCode()
        {
            const string chars = "0123456789";
            return new string(Enumerable.Repeat(chars, 5)
                .Select(s => s[_random.Next(s.Length)]).ToArray());
        }
    }
}
