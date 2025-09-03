using BalanceGame.Data;
using BalanceGame.Models;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;

namespace BalanceGame.Services
{
    public class UserService
    {
        private readonly GameDbContext _context;
        
        public UserService(GameDbContext context)
        {
            _context = context;
        }
        
        public async Task<User?> AuthenticateAsync(string username, string password)
        {
            var hashedPassword = HashPassword(password);
            return await _context.Users
                .FirstOrDefaultAsync(u => u.Username == username && u.Password == hashedPassword);
        }
        
        public async Task<User?> RegisterAsync(string username, string password)
        {
            if (await _context.Users.AnyAsync(u => u.Username == username))
            {
                return null; // Username already exists
            }
            
            var user = new User
            {
                Username = username,
                Password = HashPassword(password)
            };
            
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
            return user;
        }
        
        public async Task<User?> GetUserByUsernameAsync(string username)
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
        }
        
        private string HashPassword(string password)
        {
            using var sha256 = SHA256.Create();
            var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password + "BalanceGameSalt"));
            return Convert.ToBase64String(hashedBytes);
        }
    }
}
