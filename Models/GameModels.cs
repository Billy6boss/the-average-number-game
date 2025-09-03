namespace BalanceGame.Models
{
    public class Player
    {
        public string Username { get; set; } = string.Empty;
        public string ConnectionId { get; set; } = string.Empty;
        public bool IsReady { get; set; } = false;
        public bool IsHost { get; set; } = false;
        public int Score { get; set; } = 0;
        public int? CurrentNumber { get; set; }
        public bool HasSubmitted { get; set; } = false;
        public bool IsEliminated { get; set; } = false;
        public DateTime JoinedAt { get; set; } = DateTime.Now;
    }
    
    public class GameResult
    {
        public double AverageNumber { get; set; }
        public double TargetNumber { get; set; }
        public string WinnerUsername { get; set; } = string.Empty;
        public List<PlayerResult> Results { get; set; } = new List<PlayerResult>();
    }
    
    public class PlayerResult
    {
        public string Username { get; set; } = string.Empty;
        public int Number { get; set; }
        public double Distance { get; set; }
        public int ScoreChange { get; set; }
        public int TotalScore { get; set; }
        public bool IsWinner { get; set; }
        public bool IsEliminated { get; set; }
    }
}
