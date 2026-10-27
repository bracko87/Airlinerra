/**
 * Server-side dependency bridge for Airlinerra's Netlify base directory.
 *
 * Netlify installs npm dependencies under website/node_modules because
 * netlify.toml sets base="website", while account services are in ../server.
 * Keeping the lazy import HERE makes the function bundler resolve pinned
 * pg from the same directory as website/package.json.
 *
 * This module is never copied into the public static dist/ allowlist.
 * NEVER put secrets or production URLs in this file.
 */
export async function loadServerPostgresDriver(){
  return import('pg');
}
