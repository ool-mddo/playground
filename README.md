# ool-mddo/playground

## Setup

Pull development resources
```shell
git submodule update --init --recursive
```

Build container images

```shell
docker-compose build
```

## Generate all data

### Up containers

* common environment variables are in [.env](.env)

```shell
docker-compose up
```

### Run tasks to generate data

```shell
docker-compose run netomox-exp bundle exec rake
```

More details in [netomox-exp README.md](https://github.com/ool-mddo/netomox-exp/blob/develop/README.md)
