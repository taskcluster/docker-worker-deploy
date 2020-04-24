#!/usr/bin/env node
const { Octokit } = require('@octokit/rest');
const fs = require('fs');
const path = require('path');
const dateformat = require('dateformat');

const RELEASE_NAME = dateformat(new Date(), 'vyyyymmddHHMM', true);
const OWNER = 'taskcluster';
const REPO = 'docker-worker-deploy';

function signin() {
  if (!process.env.DOCKER_WORKER_GITHUB_TOKEN) {
    throw new Error(
      'You supply a user token thorugh the environment variable DOCKER_WORKER_GITHUB_TOKEN'
    );
  }

  const github = new Octokit({
    timeout: 5000,
    host: 'api.github.com',
    protocol: 'https',
    headers: {
      'user-agent': REPO,
    },
    rejectUnauthorized: false, // default: true
    auth: process.env.DOCKER_WORKER_GITHUB_TOKEN,
  });

  return github;
}

function createRelease(github) {
  return github.repos.createRelease({
    owner: OWNER,
    repo: REPO,
    tag_name: RELEASE_NAME,
    name: RELEASE_NAME,
  });
}

// upload a file as a release asset
function uploadFile(github, filename) {
  const stream = fs.readFileSync(filename);

  return github.repos.getReleaseByTag({
    owner: OWNER,
    repo: REPO,
    tag: RELEASE_NAME,
  }).then(result => {
    return github.repos.uploadReleaseAsset({
      owner: OWNER,
      repo: REPO,
      release_id: result.data.id,
      name: path.basename(filename),
      data: stream,
    });
  });
}

function main() {
  const github = signin();
  createRelease(github)
    .then(() => uploadFile(github, 'docker-worker.tgz'))
    .then(() => uploadFile(github, 'docker-worker-amis.json'))
    .then(() => console.log(RELEASE_NAME))
    .catch(err => {
      console.error(err.stack || err);

      // If something goes wrong we delete the release
      github.repos.getReleaseByTag({
        owner: OWNER,
        repo: REPO,
        tag: RELEASE_NAME,
      }).then(result => {
        github.repos.deleteRelease({
          owner: OWNER,
          repo: REPO,
          id: result.data.id,
        });
      });

      process.exit(1);
    });
}

process.on('unhandledRejection', (err, p) => {
  console.error(err.stack || err);
  process.exit(1);
});

main();
