using System.ComponentModel.DataAnnotations;

namespace BalanceGame.Models
{
    public class GameRoom
    {
        [Key]
        public string RoomCode { get; set; } = string.Empty;
        
        public string HostUsername { get; set; } = string.Empty;
        
        public DateTime CreatedAt { get; set; } = DateTime.Now;
        
        public bool IsActive { get; set; } = true;
        
        // Game settings
        public int RoundTimeSeconds { get; set; } = 180;
        public bool AllowChat { get; set; } = true;
        
        // Current game state
        public GameState State { get; set; } = GameState.Waiting;
        public int CurrentRound { get; set; } = 0;
        public DateTime? RoundStartTime { get; set; }
        
        // Players (stored as JSON or separate table)
        public string PlayersJson { get; set; } = "[]";
    }
    
    public enum GameState
    {
        Waiting,
        Starting,
        Playing,
        ShowingResults,
        Finished
    }
}
