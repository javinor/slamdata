var env = require("./src/Test/SlamData/Feature/Env.js");
var databaseName = "testDb";
var databaseHost = env.getEnv("CONNECTOR_HOST")();
var databasePort = env.getEnv("CONNECTOR_PORT")();
var databaseType = env.getEnv("CONNECTOR_TYPE")();
var quasarPort = env.getEnv("QUASAR_PORT")();


module.exports = {
  selenium: {
    waitTime: databaseType == "couchbase" ? 50000 : 30000
  },
  slamdataUrl: "http://localhost:" + quasarPort,
  database: {
    name: databaseName,
    type: databaseType,
    host: databaseHost,
    port: databasePort
  },
  upload: {
    filePaths: ["./test/line-delimited.json", "./test/array-wrapped.json"]
  },
  download: {
    folder: "tmp/test/downloads"
  }
}
