using BalanceGame.Data;
using BalanceGame.Models;
using Microsoft.EntityFrameworkCore;

namespace BalanceGame.Services
{
    public class GameHistoryService
    {
        private readonly GameDbContext _context;
        
        public GameHistoryService(GameDbContext context)
        {
            _context = context;
        }
        
        public async Task SaveGameResultAsync(string roomCode, GameResult result)
        {
            var histories = new List<GameHistory>();
            
            foreach (var playerResult in result.Results)
            {
                var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == playerResult.Username);
                if (user != null)
                {
                    histories.Add(new GameHistory
                    {
                        UserId = user.Id,
                        RoomCode = roomCode,
                        Round = 1, // You might want to track actual round numbers
                        PlayerNumber = playerResult.Number,
                        TargetNumber = result.TargetNumber,
                        IsWinner = playerResult.IsWinner,
                        Score = playerResult.TotalScore
                    });
                }
            }
            
            _context.GameHistories.AddRange(histories);
            await _context.SaveChangesAsync();
        }
        
        public async Task<List<GameHistory>> GetUserHistoryAsync(string username, int take = 50)
        {
            return await _context.GameHistories
                .Include(h => h.User)
                .Where(h => h.User.Username == username)
                .OrderByDescending(h => h.PlayedAt)
                .Take(take)
                .ToListAsync();
        }
        
        public async Task<List<GameHistory>> GetRoomHistoryAsync(string roomCode)
        {
            return await _context.GameHistories
                .Include(h => h.User)
                .Where(h => h.RoomCode == roomCode)
                .OrderByDescending(h => h.PlayedAt)
                .ToListAsync();
        }
    }
}
