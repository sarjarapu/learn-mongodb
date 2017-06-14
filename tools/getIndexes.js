var items = [];
db.adminCommand('listDatabases').databases.forEach(d => {
	var dbo = db.getSiblingDB(d.name);
	dbo.getCollectionNames().forEach(c => {
		var co = dbo.getCollection(c);
		co.getIndexes().forEach(i => {
			var indexSizes = co.stats(1024*1024).indexSizes;
			var item = {database: d.name, collection: c, namespace: i.ns, indexName: i.name, indexKey: i.key, indexSize: indexSizes[i.name]};
			items.push(item)
		});
	});
})
printjson(items);
