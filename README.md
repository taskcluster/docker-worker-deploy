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
