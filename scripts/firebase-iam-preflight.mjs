#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const projectId = readArg('project', 'zephyr-495115');
const projectNumber = readArg('project-number', '724639603736');
const rulesPath = readArg('rules', 'storage.rules');
const requiredRole = 'roles/firebaserules.firestoreServiceAgent';
const storageServiceAgent = `service-${projectNumber}@gcp-sa-firebasestorage.iam.gserviceaccount.com`;
const requiredMember = `serviceAccount:${storageServiceAgent}`;

const rulesSource = readFileSync(rulesPath, 'utf8');
const needsCrossServiceIam = /\bfirestore\.(get|exists)\s*\(/.test(rulesSource);

if (!needsCrossServiceIam) {
  console.log(
    `OK: ${rulesPath} does not use firestore.get()/exists(); cross-service Storage IAM is not required.`,
  );
  process.exit(0);
}

const token = await firebaseAccessToken();
const policy = await getIamPolicy(token);
const bindings = policy.bindings ?? [];
const rolesForStorageAgent = bindings
  .filter((binding) => (binding.members ?? []).includes(requiredMember))
  .map((binding) => binding.role)
  .sort();

if (!rolesForStorageAgent.includes(requiredRole)) {
  console.error('FAILED: Firebase Storage cross-service IAM is missing.');
  console.error(`Project: ${projectId} (${projectNumber})`);
  console.error(`Rules: ${rulesPath} uses firestore.get()/exists()`);
  console.error(`Required member: ${requiredMember}`);
  console.error(`Required role: ${requiredRole}`);
  console.error(
    `Current roles for member: ${rolesForStorageAgent.join(', ') || 'none'}`,
  );
  console.error(
    'Grant the required role before deploying Storage rules or trusting media smoke.',
  );
  process.exit(1);
}

console.log('OK: Firebase Storage cross-service IAM is present.');
console.log(`Project: ${projectId} (${projectNumber})`);
console.log(`Member: ${requiredMember}`);
console.log(`Roles: ${rolesForStorageAgent.join(', ')}`);

function readArg(name, fallback) {
  const prefix = `--${name}=`;
  const withEquals = process.argv.find((arg) => arg.startsWith(prefix));
  if (withEquals) return withEquals.slice(prefix.length);

  const index = process.argv.indexOf(`--${name}`);
  if (index >= 0 && process.argv[index + 1]) return process.argv[index + 1];

  const envName = name.toUpperCase().replaceAll('-', '_');
  return process.env[`ZEPHYR_${envName}`] || fallback;
}

async function firebaseAccessToken() {
  try {
    const auth = require('firebase-tools/lib/auth');
    const scopes = require('firebase-tools/lib/scopes');
    const { configstore } = require('firebase-tools/lib/configstore');
    const tokens = configstore.get('tokens');
    const refreshToken = tokens?.refresh_token || process.env.FIREBASE_TOKEN;

    if (!refreshToken) {
      throw new Error('No Firebase CLI refresh token is available.');
    }

    const access = await auth.getAccessToken(refreshToken, [
      scopes.CLOUD_PLATFORM,
    ]);
    if (!access?.access_token) {
      throw new Error('Firebase CLI did not return an access token.');
    }
    return access.access_token;
  } catch (error) {
    throw new Error(
      `Unable to obtain Firebase access token. Run firebase login or provide Firebase CLI auth. ${error.message}`,
    );
  }
}

async function getIamPolicy(accessToken) {
  const response = await fetch(
    `https://cloudresourcemanager.googleapis.com/v1/projects/${projectId}:getIamPolicy`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    },
  );

  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `getIamPolicy failed for ${projectId}: ${response.status} ${text.slice(0, 500)}`,
    );
  }
  return JSON.parse(text);
}
