import com.mongodb.MongoClient;
import com.mongodb.MongoClientURI;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import model.Zip;
import org.bson.BsonDocument;
import org.bson.Document;
import org.bson.conversions.Bson;

import java.util.ArrayList;
import java.util.List;

import static com.mongodb.client.model.Filters.and;
import static com.mongodb.client.model.Filters.eq;
import static com.mongodb.client.model.Filters.in;

/**
 * Created by shyamarjarapu on 1/10/17.
 */
public class Application {
    public static void main(String[] args) {

        String url = "mongodb://Shyams-MacBook-Pro.local:27017/sample";
        MongoClientURI clientURI = new MongoClientURI(url);
        MongoClient client = new MongoClient(clientURI);

        MongoDatabase database = client.getDatabase("sample");

        MongoCollection<Document> collection = database.getCollection("zips");


        Bson query = and(eq("state", "CA"), in("city", new String[]{"OAKLAND", "SAN FRANCISCO"}));

        FindIterable<Document> iterable = collection.find(query);


        List<Zip> zips = new ArrayList<Zip>();
        for (Document document : iterable) {
            zips.add(createZip(document));
        }

        for (Zip zip : zips) {
            System.out.println(zip.toString());
        }

    }

    private static Zip createZip(Document document) {
        Zip item = new Zip();
        item.setId(document.getObjectId("_id"));
        item.setCity(document.getString("city"));
        item.setState(document.getString("state"));
        item.setPop(document.getInteger("pop"));
        return item;
    }
}

