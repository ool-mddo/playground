# ool-mddo/playground

## setup

Pull development resources
```shell
git submodule update --init --recursive
```

Build container images
```shell
docker-compose build
```

Run containers
```shell
docker-compose up
```

## Generate all data

```shell
docker-compose run netomox-exp bundle exec rake
```
More details in [netomox-exp README.md](https://github.com/ool-mddo/netomox-exp/README.md)
