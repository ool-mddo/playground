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

Note: Common environment variables are in [.env](.env)

```shell
docker-compose up
```

### Run tasks to generate data

Exec rake directly

```shell
docker-compose run netomox-exp bundle exec rake
```

or attach shell to the container and exec inside it

```shell
docker-compose run netomox-exp bash
bundle exec rake
```

More details in [netomox-exp README.md](https://github.com/ool-mddo/netomox-exp/blob/develop/README.md)
