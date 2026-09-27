"use strict";

const rows = document.getElementById("servers");
const connection = document.getElementById("connection");
const refreshButton = document.getElementById("refresh");
const filter = document.getElementById("filter");
let servers = [];
let receivedAt = 0;
let timer;
let busy = false;
let nextRefresh = 0;

function cell(row, primary, secondary, className) {
  const td = document.createElement("td");
  if (className) td.className = className;
  const text = document.createElement("strong");
  text.textContent = primary;
  td.append(text);
  if (secondary !== undefined) {
    const detail = document.createElement("span");
    detail.className = "secondary";
    detail.textContent = secondary;
    td.append(detail);
  }
  row.append(td);
}

function render() {
  const search = filter.value.trim().toLowerCase();
  const visible = servers.filter(server => [server.name, server.address, server.map,
    server.map_title, server.mode, server.weapon_rules, server.version, server.protocol]
    .some(value => String(value).toLowerCase().includes(search)));
  const fragment = document.createDocumentFragment();
  for (const server of visible) {
    const row = document.createElement("tr");
    const address = server.address.includes(":") ? `[${server.address}]` : server.address;
    cell(row, server.name, `${address}:${server.game_port} · query ${server.query_port}`);
    cell(row, server.map_title, `${server.map} · ${server.mode.toUpperCase()} / ${server.weapon_rules}`);
    cell(row, `${server.humans} / ${server.capacity}`);
    cell(row, server.bots);
    cell(row, server.spectators);
    cell(row, server.reserved);
    cell(row, server.open_slots, undefined, "seats");
    cell(row, server.version, server.protocol);
    const age = server.age_seconds + Math.floor((Date.now() - receivedAt) / 1000);
    cell(row, server.state, `${age}s ago · ${server.source === "local" ? "auto-discovered" : "registered"}`);
    fragment.append(row);
  }
  rows.replaceChildren(fragment);
  const empty = document.getElementById("empty");
  empty.hidden = visible.length > 0;
  empty.textContent = servers.length ? "No servers match your filter." : "No servers are currently listed.";
  for (const [id, field] of [["humans", "humans"], ["bots", "bots"], ["open", "open_slots"]]) {
    document.getElementById(`total-${id}`).textContent = servers.reduce((sum, server) => sum + server[field], 0);
  }
  document.getElementById("total-servers").textContent = servers.length;
}

async function refresh() {
  if (busy) return;
  clearTimeout(timer);
  if (Date.now() < nextRefresh) {
    timer = setTimeout(refresh, nextRefresh - Date.now());
    return;
  }
  busy = true;
  refreshButton.disabled = true;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  let delay = 10000;
  try {
    // Relative URLs support a directory mounted under a reverse-proxy prefix.
    const response = await fetch("v1/servers", {cache: "no-store", signal: controller.signal});
    if (!response.ok) {
      if (response.status === 429) delay = 60000;
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    if (data.schema !== 1 || !Array.isArray(data.servers)) throw new Error("Invalid directory response");
    servers = data.servers.sort((a, b) => b.humans - a.humans || a.name.localeCompare(b.name));
    receivedAt = Date.now();
    render();
    connection.textContent = `Live · updated ${new Date(receivedAt).toLocaleTimeString()}`;
    connection.className = "";
  } catch (error) {
    connection.textContent = receivedAt
      ? `Directory unavailable · showing data from ${new Date(receivedAt).toLocaleTimeString()}`
      : "Directory unavailable · retrying automatically";
    connection.className = "error";
    if (receivedAt) render();
    else document.getElementById("empty").textContent = "Waiting for the directory to respond.";
  } finally {
    clearTimeout(timeout);
    busy = false;
    refreshButton.disabled = false;
    nextRefresh = Date.now() + (delay === 60000 ? delay : 2500);
    timer = setTimeout(refresh, delay);
  }
}

filter.addEventListener("input", render);
refreshButton.addEventListener("click", refresh);
refresh();
