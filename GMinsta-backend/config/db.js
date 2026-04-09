const dns = require("dns");
const { promisify } = require("util");
const dotenv = require("dotenv");
const mongoose = require("mongoose");

dotenv.config();

const ATLAS_DNS_SERVERS = ["8.8.8.8", "1.1.1.1"];

const buildStandardAtlasUri = async (mongoUri) => {
  const srvPrefix = "mongodb+srv://";
  if (!mongoUri.startsWith(srvPrefix)) {
    return mongoUri;
  }

  const rest = mongoUri.slice(srvPrefix.length);
  const pathStartIndex = rest.indexOf("/");
  if (pathStartIndex === -1) {
    throw new Error("Invalid MongoDB Atlas SRV URI.");
  }

  const authority = rest.slice(0, pathStartIndex);
  const pathAndQuery = rest.slice(pathStartIndex);
  const atIndex = authority.lastIndexOf("@");
  const authPart = atIndex >= 0 ? authority.slice(0, atIndex + 1) : "";
  const hostname = atIndex >= 0 ? authority.slice(atIndex + 1) : authority;
  const queryIndex = pathAndQuery.indexOf("?");
  const pathname =
    queryIndex >= 0 ? pathAndQuery.slice(0, queryIndex) : pathAndQuery;
  const rawQuery = queryIndex >= 0 ? pathAndQuery.slice(queryIndex + 1) : "";

  const resolver = new dns.Resolver();
  resolver.setServers(ATLAS_DNS_SERVERS);

  const resolveSrv = promisify(resolver.resolveSrv).bind(resolver);
  const resolveTxt = promisify(resolver.resolveTxt).bind(resolver);

  const [srvRecords, txtRecords] = await Promise.all([
    resolveSrv(`_mongodb._tcp.${hostname}`),
    resolveTxt(hostname).catch(() => [])
  ]);

  const connectionHosts = srvRecords
    .sort((left, right) => left.name.localeCompare(right.name))
    .map((record) => `${record.name}:${record.port}`)
    .join(",");

  const mergedParams = new URLSearchParams();
  txtRecords
    .flat()
    .filter(Boolean)
    .forEach((entry) => {
      new URLSearchParams(entry).forEach((value, key) => {
        mergedParams.set(key, value);
      });
    });

  new URLSearchParams(rawQuery).forEach((value, key) => {
    mergedParams.set(key, value);
  });

  if (!mergedParams.has("tls") && !mergedParams.has("ssl")) {
    mergedParams.set("tls", "true");
  }

  const query = mergedParams.toString();
  return `mongodb://${authPart}${connectionHosts}${pathname}${
    query ? `?${query}` : ""
  }`;
};

const connectDB = async () => {
  const mongoUri = process.env.MONGO_URI;

  if (!mongoUri) {
    throw new Error("MONGO_URI is not set in the environment.");
  }

  mongoose.set("strictQuery", true);

  try {
    await mongoose.connect(mongoUri);
  } catch (error) {
    if (error?.code === "ECONNREFUSED" && error?.syscall === "querySrv") {
      const fallbackMongoUri = await buildStandardAtlasUri(mongoUri);
      await mongoose.connect(fallbackMongoUri);
    }
    else {
      throw error;
    }
  }

  console.log(
    `MongoDB connected: ${mongoose.connection.host}/${mongoose.connection.name}`
  );
};

module.exports = connectDB;
