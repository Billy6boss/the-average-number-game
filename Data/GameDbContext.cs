using Microsoft.EntityFrameworkCore;
using BalanceGame.Models;

namespace BalanceGame.Data
{
    public class GameDbContext : DbContext
    {
        public GameDbContext(DbContextOptions<GameDbContext> options) : base(options)
        {
        }
        
        public DbSet<User> Users { get; set; }
        public DbSet<GameRoom> GameRooms { get; set; }
        public DbSet<GameHistory> GameHistories { get; set; }
        
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            // Configure User
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasIndex(e => e.Username).IsUnique();
            });
            
            // Configure GameRoom
            modelBuilder.Entity<GameRoom>(entity =>
            {
                entity.HasKey(e => e.RoomCode);
                entity.Property(e => e.RoomCode).HasMaxLength(5);
            });
            
            // Configure GameHistory
            modelBuilder.Entity<GameHistory>(entity =>
            {
                entity.HasOne(d => d.User)
                    .WithMany(p => p.GameHistories)
                    .HasForeignKey(d => d.UserId);
            });
        }
    }
}
