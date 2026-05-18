
using System.Runtime.InteropServices.JavaScript;
using Microsoft.Extensions.FileSystemGlobbing.Internal.Patterns;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllersWithViews();

var app = builder.Build();

var author = "Fabian Skrzypczyński";
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
var launchDate = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");

Console.WriteLine($"========================================");
Console.WriteLine($"Data uruchomienia: {launchDate}");
Console.WriteLine($"Autor: {author}");
Console.WriteLine($"Port TCP: {port}");
Console.WriteLine($"========================================");

app.UseRouting();
app.UseStaticFiles();

app.MapControllerRoute(
    name: "default",
    pattern:"{controller=Weather}/{action=Index}/{id?}"
    );
app.Run();