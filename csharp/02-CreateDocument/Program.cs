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

                List<BsonDocument> bsonDocs = GetBsonDocuments();
                coll.InsertMany(bsonDocs);

                Console.WriteLine("");
                Console.WriteLine("Creation of mulitple documents is completed. Let's read them all from database");
                coll.Find(new BsonDocument()).ToList().ForEach(d => Console.WriteLine("  {0}", d));

                Console.WriteLine("");
                Console.WriteLine("Congratulations! You made it through creation of documents in MongoDB");
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

        private static List<BsonDocument> GetBsonDocuments()
        {
            var rand = new Random(100);
            var cities = new [] {
                new Tuple<string, string>("Newark", "NJ" ),
                new Tuple<string, string>("New York", "NY"),
                new Tuple<string, string>("Dallas", "TX"),
                new Tuple<string, string>("Austin", "TX"),
                new Tuple<string, string>("San Francisco", "CA"),
                new Tuple<string, string>("Mountain View", "CA"),
                new Tuple<string, string>("Seattle", "WA"),
                new Tuple<string, string>("Salt Lake City", "UT")
            };
            var documents = new List<BsonDocument>();
            for(var i = 0; i < 5; i++)
            {
                var city = cities[rand.Next(cities.Length)];
                var likes = GetRandomLikes(rand);
                // document has string keys with values as string/int/array of strings/subdocument
                var data = new Dictionary<string, object>{
                    { "name", $"F{i} N{i}" },
                    { "linkedin", $"https://www.linkedin.com/in/fn{i}" },
                    { "connections", rand.Next(10000) },
                    { "likes" , likes },
                    { "address" , new Dictionary<string, object>{
                        { "city", city.Item1 }, {"state", city.Item2 }
                    } }
                };
                documents.Add(new BsonDocument(data));
            }
            return documents;
        }

        private static string[] GetRandomLikes(Random rand)
        {
            var likes = new[] { ".net", "nodejs", "mongodb", "java", "oracle", "ruby", "python" };
            var count = rand.Next(likes.Length + 1);
            if (count > 0)
            {
                var selected = new string[count];
                for (int i = 0; i < count; i++)
                {
                    var like = likes[rand.Next(likes.Length)];
                    if (!selected.Contains(like))
                    {
                        selected[i] = like;
                    }
                }
                return selected;
            }
            return null;
        }
    }
}
