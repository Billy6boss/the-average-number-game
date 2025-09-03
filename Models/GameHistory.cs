using System.ComponentModel.DataAnnotations;

namespace BalanceGame.Models
{
    public class GameHistory
    {
        [Key]
        public int Id { get; set; }
        
        public int UserId { get; set; }
        public string RoomCode { get; set; } = string.Empty;
        public int Round { get; set; }
        public int PlayerNumber { get; set; }
        public double TargetNumber { get; set; }
        public bool IsWinner { get; set; }
        public int Score { get; set; }
        public DateTime PlayedAt { get; set; } = DateTime.Now;
        
        // Navigation properties
        public virtual User User { get; set; } = null!;
    }
}
