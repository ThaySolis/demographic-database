// source: https://stackoverflow.com/a/33216902

var conn;
var interval = 100; // 100 Milliseconds polling
var timeout = 10000; // 10 Seconds timeout
var startTime = new Date();
connectionUrl = connectionUrl.split('/')[2];

if (connectionUrl.indexOf('@') !== -1) {
    // Has auth (doesn't need auth for test connection)
    connectionUrl = connectionUrl.split('@')[1];
}

while (conn === undefined) {
    try {
        var elapsed = (new Date() - startTime);
        print("Attempting to connect to " + connectionUrl + " elapsed: " + elapsed + "ms");
        conn = new Mongo(connectionUrl);
    } catch (error) {
        print(error);

        if ((new Date() - startTime) >= timeout) {
            print("ERROR: Failed to establish connection within timeout (" + timeout + "ms)");
            quit(1);
        } else {
            sleep(interval);
        }
    }
}

print("MongoDB connection established in " + (new Date() - startTime) + "ms");
