Building EC2 AMIs for docker-worker
===================================

First of all, you need proper taskcluster credentials. You can use the
[taskcluster-shell](https://github.com/taskcluster/taskcluster/clients/client-shell)
tool to get it:
```sh
# eval $(taskcluster signin)
```
You also need the
[Taskcluster team passwordstore repo](https://github.com/taskcluster/passwordstore-garbage)
proper configured. Talk to :dustin to know how to get access to it.
The deploy scripts require node version >= 12.11.0.
With all these done, type:
```sh
# ./deploy.sh <docker-worker source code path> <build target>
```
To build docker-worker AMIs. The build target is either `app` or `base`. The base image
is used to accelarate the process the more common app image. You can also tag a github
release with:

```sh
# ./release.sh
```

To be able to do a Github release, you need a proper key stored in the environment
variable `DOCKER_WORKER_GITHUB_TOKEN`.

The generate AMI IDs must be update in the
[ci-configuration](https://hg.mozilla.org/ci/ci-configuration/)
and [community-tc-config](https://github.com/mozilla/community-tc-config) repositories.


Building under Vagrant
======================

Install vagrant on your system, and a virtualisation backend, such as Virtual Box.

For example, on macOS:

```
$ brew install --cask vagrant
$ brew install --cask virtualbox
```

Install a vagrant provider plugin to match the backend you chose, and install the `vagrant-reload` plugin:

```
$ vagrant plugin update
$ vagrant plugin install virtualbox
$ vagrant plugin install vagrant-reload
```

Install VirtualBox Guest Additions plugin:

```
$ vagrant plugin install vagrant-vbguest
```

Clone `taskcluster`, and then clone `docker-worker-deploy` inside the `workers`
directory so that `docker-worker-deploy` and `docker-worker` are _sibling_
directories on your system, e.g.

```
$ git clone git@github.com:taskcluster/taskcluster.git
$ cd taskcluster/workers
$ git clone git@github.com:taskcluster/docker-worker-deploy.git
```

Bring up the vagrant machine:

```
$ cd docker-worker
$ vagrant up
```

Install the VirtualBox Guest Additions on the VM and restart it:

```
$ vagrant vbguest
$ vagrant reload default
```

SSH into the machine, initialise the `/docker-worker-deploy` directory, and build the docker images locally:

```
$ vagrant ssh
$ cd /docker-worker-deploy
$ ./vagrant.sh
$ ./build.sh
$ curl -o- -L https://yarnpkg.com/install.sh | bash
$ exit
$ vagrant ssh
$ yarn install
```

Export credentials for running integration tests:

```
$ export TASKCLUSTER_ROOT_URL='......'
$ export TASKCLUSTER_CLIENT_ID='......'
$ export TASKCLUSTER_ACCESS_TOKEN='......'
$ export TASKCLUSTER_CERTIFICATE='......'   # not needed if using "permanent" credentials
```

Run tests:

```
$ ./node_modules/mocha/bin/mocha
```
