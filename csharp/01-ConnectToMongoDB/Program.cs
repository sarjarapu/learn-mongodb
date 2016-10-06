using MongoDB.Driver;
using System;
using System.Configuration;
using System.Linq;

namespace ConnectToMongoDB
{
    class Program
    {
        static void Main(string[] args)
        {
            var program = new Program();
            program.Run();
            
            Console.WriteLine("Press ENTER to exit");
            Console.ReadLine();
        }

        void Run()
        {
            var connStr = ConfigurationManager.AppSettings.Get("mongoDBConnStr");
            try
            {
                Console.WriteLine("Connecting to MongoDB @ {0}", connStr);

                var client = new MongoClient(connStr);
                
                Console.WriteLine("Listing all databases on server");
                using (var cursor = client.ListDatabases())
                {
                    foreach (var doc in cursor.ToList())
                    {
                        Console.WriteLine("\t{0}", doc["name"]);
                    }
                }
                Console.WriteLine("Congratulations! You made it through connecting to MongoDB");
            }
            catch (TimeoutException e)
            {
                Console.WriteLine("Error connecting to MongoDB: {0}", connStr);
                Console.WriteLine(e.Message);
            }
            Console.WriteLine("");
        }
    }
}
