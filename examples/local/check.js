// Run with Node in the uptime-kuma container, which shares the host's
// network and has socket.io-client: `podman exec -i uptime-kuma node - setup < check.js`.
// "setup" creates the admin and two monitors, one for Uptime Kuma itself and
// one for a closed port, and waits for the first to come up and the second to
// go down. "verify" logs in again and waits for fresh heartbeats with the same
// results, which shows the monitors and the account outlived the change.
const { io } = require("/app/node_modules/socket.io-client");

const url = "http://127.0.0.1:3001";
const user = "admin";
const pass = "ci-check-Password-1";
const what = process.argv[2];

const fail = (m) => {
  console.error("FAIL: " + m);
  process.exit(1);
};
setTimeout(() => fail("timed out"), 180000);

const socket = io(url, { transports: ["websocket"], reconnection: false });
const call = (event, ...args) => new Promise((resolve) => socket.emit(event, ...args, resolve));
const ids = {};
const beats = [];
socket.on("monitorList", (list) => Object.values(list).forEach((m) => (ids[m.name] = m.id)));
socket.on("heartbeat", (b) => beats.push(b));
socket.on("connect_error", (e) => fail("connect: " + e.message));

const monitor = (name, target) => ({
  type: "http",
  name,
  url: target,
  method: "GET",
  interval: 20,
  retryInterval: 20,
  maxretries: 0,
  timeout: 10,
  accepted_statuscodes: ["200-299"],
  notificationIDList: {},
  conditions: [],
  kafkaProducerBrokers: [],
  kafkaProducerSaslOptions: {},
  rabbitmqNodes: [],
  active: true,
});

// Waits for the named monitor's next heartbeat. Uptime Kuma only sends
// "heartbeat" for checks it runs while we're connected.
const waitFor = async (name, status) => {
  for (;;) {
    const b = beats.find((x) => x.monitorID === ids[name]);
    if (b) {
      if (b.status !== status) fail(`${name} reported ${b.status}, wanted ${status}: ${b.msg}`);
      return;
    }
    await new Promise((r) => setTimeout(r, 500));
  }
};

// Uptime Kuma sends "info" before it adds its handlers, so anything sent
// before it arrives is dropped.
socket.once("info", async () => {
  if (what === "setup") {
    if (!(await call("needSetup"))) fail("an admin already exists");
    const s = await call("setup", user, pass);
    if (!s.ok) fail("setup: " + s.msg);
  }
  const bad = await call("login", { username: user, password: "wrong-password", token: "" });
  if (bad.ok) fail("a wrong password logged in");
  const l = await call("login", { username: user, password: pass, token: "" });
  if (!l.ok) fail("login: " + l.msg);
  if (what === "setup") {
    for (const [n, t] of [["self", url], ["closed", "http://127.0.0.1:9"]]) {
      const r = await call("add", monitor(n, t));
      if (!r.ok) fail("add " + n + ": " + r.msg);
      ids[n] = r.monitorID;
    }
  }
  await waitFor("self", 1);
  await waitFor("closed", 0);
  console.log(what + ": ok");
  process.exit(0);
});
