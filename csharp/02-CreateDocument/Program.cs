using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CreateDocument
{
    class Program
    {
        const string DatabaseName = "learn-mongodb";
        const string CollectionName = "person";

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
                var db = client.GetDatabase(DatabaseName);
                var coll = db.GetCollection<BsonDocument>(CollectionName);
                BsonDocument bsonDoc = GetBsonDocument();

                Console.WriteLine($"DB: {DatabaseName}, Collection: {CollectionName}\nCreate Document: {bsonDoc} ");
                coll.InsertOne(bsonDoc);

                Console.WriteLine("");
                Console.WriteLine("Creation of document is completed. Let's read it back from database");

                // Find all documents db.person.findOne({})
                var doc = coll.Find(new BsonDocument()).Limit(1).FirstOrDefault();
                Console.WriteLine("  {0}\n", doc);

                Console.WriteLine("");
                Console.WriteLine("Congratulations! You made it through create documents in MongoDB");
            }
            catch (TimeoutException e)
            {
                Console.WriteLine(e.Message);
            }
            Console.WriteLine("");
        }

        private static BsonDocument GetBsonDocument()
        {
            // document has string keys with values as string/int/array of strings/subdocument
            var data = new Dictionary<string, object>{
                    { "name", "Shyam Arjarapu" },
                    { "linkedin", "https://www.linkedin.com/in/shyamarjarapu" },
                    { "connections", 291 },
                    { "likes" , new[] { ".net", "nodejs", "mongodb" } },
                    { "address" , new Dictionary<string, object>{
                        { "city", "Austin" }, {"state", "TX" }
                    } }
                };
            return new BsonDocument(data);
        }
    }
}
