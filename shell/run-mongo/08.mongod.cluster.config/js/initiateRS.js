rs.initiate({_id: "shard1", members: [{host: "127.0.0.1:29020", _id: 1}]});
rs.add("127.0.0.1:29021");
rs.add("127.0.0.1:29022");